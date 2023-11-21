resource "aws_kms_key" "uat_secrets_key" {
  description             = "Key for encrypting k8s secret data at rest"
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

    tags = merge(local.tags,tomap({"Name" = "uat_secrets_key"}))
}

resource "aws_kms_alias" "uat_secrets_key_alias" {
  name          = "alias/uat_secrets_key"
  target_key_id = aws_kms_key.uat_secrets_key.id
}

output "uat_secrets_key_arn" {
    value = aws_kms_key.uat_secrets_key.arn
}