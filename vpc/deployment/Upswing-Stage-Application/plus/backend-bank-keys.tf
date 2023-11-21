
locals {
  enabled_fsi = ["UTKSIN", "AXISIN", "BJFLIN", "STFCIN", "SMCBIN", "SOININ"]
}
resource "aws_kms_key" "bank_keys" {
  count = length(local.enabled_fsi)
  description             = "Key for encrypting ${local.enabled_fsi[count.index]} storage"
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
   tags = {
      Environment = "Alpha"
      FSI        = "${local.enabled_fsi[count.index]}"
    }
}

output "bank_keys_arn" {
  value = aws_kms_key.bank_keys[*].arn
}

resource "aws_kms_alias" "bank_keys_alias" {
  count = length(local.enabled_fsi)
  name          = "alias/${local.enabled_fsi[count.index]}"
  target_key_id = aws_kms_key.bank_keys[count.index].id
}

