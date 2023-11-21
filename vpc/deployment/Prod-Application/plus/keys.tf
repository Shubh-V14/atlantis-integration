resource "aws_kms_key" "ec2_session_key" {
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

    tags = merge(local.tags,tomap({"Name" = "ec2-session-key"}))
}

output "ec2_session_key_arn" {
  value = aws_kms_key.ec2_session_key.arn
}

resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/ec2_session_key"
  target_key_id = aws_kms_key.ec2_session_key.key_id
}



resource "aws_kms_key" "ups_backup_encryption" {
  description             = "Key for encrypting backups at rest"
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

    tags = merge(local.tags,tomap({"Name" = "rds_backup_encrypt"}))
}

resource "aws_kms_alias" "rds_backup_key_alias" {
  name          = "alias/rds_backup_encrypt"
  target_key_id = aws_kms_key.ups_backup_encryption.id
}