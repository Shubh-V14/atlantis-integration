#This module expects a aws-secret secret_binary to be passed
#It checks if the required keys are defined and if so, it adds them to kubernetes secret
variable secret_binary {}
variable secret_keys {
  type = list(string)
  default = []
}
variable name {}
variable namespace {}
locals {
  secrets_value = jsondecode(var.secret_binary)
  secrets_keys = var.secret_keys
  secrets_data = {for k in local.secrets_keys: k => base64decode(local.secrets_value[k]) if lookup(local.secrets_value, k, false) != false ? true : false}
}


resource "kubernetes_secret_v1" "secrets" {
  metadata {
    name = var.name
    namespace = var.namespace
  }
  data = local.secrets_data
}
