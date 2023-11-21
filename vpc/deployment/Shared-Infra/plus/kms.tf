resource "aws_kms_key" "ecr_key" {
  description             = "Key for encrypting ecr storage"
  deletion_window_in_days = 10
  key_usage = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
  policy                   = jsonencode(
        {
            Statement = [
                {
        "Sid"= "Allow use of the key for all the accounts in the organization",
        "Effect"= "Allow",
         "Principal"= {
        "AWS"= jsondecode(var.org_arns)
        },
        "Action"= [
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
    ],
        "Resource"= "*"
    },
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
    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ecr_key"}))
}

output "ecr_key_arn" {
  value = aws_kms_key.ecr_key.arn
}

resource "aws_kms_alias" "ecr_key_alias" {
  name          = "alias/ecr_key"
  target_key_id = aws_kms_key.ecr_key.key_id
}

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

    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ebs_key"}))
}

output "ebs_key_arn" {
  value = aws_kms_key.ebs_key.arn
}

resource "aws_kms_alias" "ebs_key_alias" {
  name          = "alias/ebs_key"
  target_key_id = aws_kms_key.ebs_key.key_id
}


