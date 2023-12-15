resource "aws_kms_key" "vault_autounseal" {
  description             = "Key for unsealing vault secret"
  deletion_window_in_days = 10
  key_usage = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
  policy                   = jsonencode(
        {
            Statement = [
      {
        "Sid"= "Allow current account to administer the key"
        "Effect"= "Allow",
         "Principal"= {
        "AWS"= "arn:aws:iam::${var.account_id}:root"
        },
        "Action"= "kms:*",
        "Resource"= "*"
        }
            ]
            Version   = "2012-10-17"
        }
    )

  tags = merge(local.tags,tomap({"Name" = "vault_autounseal"}))
}

output "vault_unseal_key_arn" {
  value = aws_kms_key.vault_autounseal.arn
}

resource "aws_kms_alias" "vault_autounseal_alias" {
  name          = "alias/vault_autounseal"
  target_key_id = aws_kms_key.vault_autounseal.key_id
}

# aws_iam_policy.vault_unseal_policy:
resource "aws_iam_policy" "vault_unseal_policy" {
    description = "vault-unseal-permissions"
    name        = "vault-unseal-permissions"
    policy      = <<EOT
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
            "Resource": "${aws_kms_key.vault_autounseal.arn}"
        }
    ]
}
EOT
    tags = merge(local.tags,tomap({"Name" = "vault-unseal-permissions"}))
    tags_all    = {}
}

locals {
    vault_namespace = "vault"
    vault_serviceaccount = "vaultsa"
}

# aws_iam_role.vault_unseal_role:
resource "aws_iam_role" "vault_unseal_role" {
    assume_role_policy    =  <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${var.account_id}:oidc-provider/${local.oidc_provider_url}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider_url}:aud": "sts.amazonaws.com",
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.vault_namespace}:${local.vault_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "vault-unseal-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.vault_unseal_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "vault-unseal-role"
    path                  = "/"

    tags = merge(local.tags,tomap({"Name" = "vault-unseal-role"}))

}