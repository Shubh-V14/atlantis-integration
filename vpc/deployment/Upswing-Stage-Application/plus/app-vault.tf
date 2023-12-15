module "vault_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "Customer managed key for vault "

  # Policy
  key_administrators = [
    "arn:aws:iam::${var.account_id}:root"
  ]

  aliases = ["vault/auto_unseal"]

  tags = local.tags
}

locals {
  stage_account_kms_arn = data.terraform_remote_state.stage_account.outputs.vault_autounseal_key_arn
}

module "vault_role" {
  source = "../../../modules/app_role/v1"
  name = "vault"
  namespace = "vault"
  serviceaccount = "vaultsa"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id

  iam_policy = <<EOT
{
"Version": "2012-10-17",
"Statement": [
  {
      "Sid": "AllowKMSForUnseal",
      "Effect": "Allow",
      "Action": [
         "kms:Encrypt",
         "kms:Decrypt",
         "kms:DescribeKey"
      ],
      "Resource": [
        "${module.vault_kms_key.key_arn}",
        "${local.stage_account_kms_arn}"
        ]
  }
  ]
}
EOT
}

output "vault_role_arn" {
  value = module.vault_role.role_arn
}

output "vault_auto_unseal_key_id" {
  value = module.vault_kms_key.key_id
}

module "vault_secrets" {
  source = "../../../modules/app_secret/v1"
  name = "vault-secrets"
  namespace = "vault"
  secret_keys = ["postgres_uri"]
  secret_binary = module.vault_secret.secret_binary
}