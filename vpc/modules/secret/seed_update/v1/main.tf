#This module is used to init the secret and update thereforth for new keys
#Value for a field can only be set once, and if update is required, has to be done
#via aws cli
#for a variant, like stage, call this module only once, calling multiple times with no var
#will cause init data to override any existing secrets
#if required to call again, just import the init version from existing secret to avoid
#override
variable variant {}

variable "secrets" {
  type = map(string)
}

variable name {}

variable kms_key_id {}

resource "aws_secretsmanager_secret" "main" {
  name = "${var.variant}_${var.name}_secrets"
  kms_key_id = var.kms_key_id
}



resource "aws_secretsmanager_secret_version" "init" {
  secret_id     = aws_secretsmanager_secret.main.id
  secret_binary = base64encode(jsonencode({init: true}))
  #ignoring secret_binary so that init is only done once
  lifecycle {
    ignore_changes = [secret_binary]
  }
}

#check version after init is done or for subsequent calls
data "aws_secretsmanager_secret_version" "pre" {
  secret_id = aws_secretsmanager_secret.main.id
  depends_on = [aws_secretsmanager_secret_version.init]
}

locals {
  current_values = jsondecode(data.aws_secretsmanager_secret_version.pre.secret_binary)
  #Only do new field initialization, updates to existing fields in the secret would not take affect and needs
  #to be done via aws cli separately
  non_null_values = { for k,v in var.secrets: k => v if v != null }
}

locals {
  #this will ensure only new fields are added to the secret
  #no update can be done using this module
  updated_values = merge(local.non_null_values, local.current_values)
}


resource "aws_secretsmanager_secret_version" "update" {
  secret_id     = aws_secretsmanager_secret.main.id
  secret_binary = base64encode(jsonencode(local.updated_values))
}


data "aws_secretsmanager_secret_version" "main" {
  secret_id = aws_secretsmanager_secret.main.id
  depends_on = [aws_secretsmanager_secret_version.update]
}

output "secret_binary" {
  value = data.aws_secretsmanager_secret_version.main.secret_binary
}