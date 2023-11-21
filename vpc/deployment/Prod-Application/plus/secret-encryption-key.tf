
resource "aws_kms_key" "ebs_key" {
  description = "Key for ebs volumes"
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

    tags = merge(local.tags,tomap({"Name" = "ebs-key"}))
}

output "ebs_key_arn" {
  value = aws_kms_key.ebs_key.arn
}

resource "aws_kms_alias" "ebs_key_alias" {
  name          = "alias/ebs_key"
  target_key_id = aws_kms_key.ebs_key.key_id
}

resource "aws_kms_key" "secrets_encryption_key" {
  description = "Key for encrypting ec2 session"
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

    tags = merge(local.tags,tomap({"Name" = "secrets-encryption-key"}))
}

output "secrets_encryption_key_arn" {
  value = aws_kms_key.secrets_encryption_key.arn
}

resource "aws_kms_alias" "secrets_encryption_key_alias" {
  name          = "alias/secrets_encryption_key"
  target_key_id = aws_kms_key.secrets_encryption_key.key_id
}
