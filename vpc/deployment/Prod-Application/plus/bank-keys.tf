
locals {
  enabled_fsi = ["UTKSIN", "AXISIN", "BJFLIN", "STFCIN", "SMCBIN"]
}
resource "aws_kms_key" "in1_bank_keys" {
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
      Environment = "IN1"
      FSI        = "${local.enabled_fsi[count.index]}"
    }
}

output "in1_bank_keys_arn" {
  value = aws_kms_key.in1_bank_keys[*].arn
}

resource "aws_kms_alias" "in1_bank_keys_alias" {
  count = length(local.enabled_fsi)
  name          = "alias/in1_${local.enabled_fsi[count.index]}"
  target_key_id = aws_kms_key.in1_bank_keys[count.index].id
}




resource "aws_iam_policy" "access_to_in1_bank_keys" {
    description = "ups-prod-in1-bank-keys-permissions"
    name        = "ups-prod-in1-bank-keys-permissions"
  policy                   = jsonencode(
        {
            Statement = [
      {
        "Sid"= "AllowAccessToBankKeys"
        "Effect"= "Allow",
        "Action"= [
       "kms:Encrypt",
       "kms:Decrypt",
       "kms:ReEncrypt*",
       "kms:GenerateDataKey*",
       "kms:DescribeKey",
       "kms:CreateGrant" 

   ],
        "Resource"= aws_kms_key.in1_bank_keys[*].arn
        }
            ]
            Version   = "2012-10-17"
        }
    )
   tags = {
      Environment = "prod"
      Name        = "ups-prod-in1-bank-keys-permissions"
    }
}