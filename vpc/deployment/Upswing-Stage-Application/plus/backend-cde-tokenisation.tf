
resource "aws_kms_key" "cde_tokenisation_key" {
  description             = "Key for encrypting tokenisation storage"
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
      Environment = "Stage"
      Name        = "tokenisation"
    }
}

output "cde_tokenisation_key_arn" {
  value = aws_kms_key.cde_tokenisation_key.arn
}

resource "aws_kms_alias" "cde_tokenisation_key_alias" {
  name          = "alias/cde_tokenisation"
  target_key_id = aws_kms_key.cde_tokenisation_key.id
}

# aws_iam_policy.cde_tokenisation_policy:
resource "aws_iam_policy" "cde_tokenisation_policy" {
    description = "cde-tokenisation-permissions"
    name        = "cde-tokenisation-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCreateTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateTable"
            ],
            "Resource": [
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/*"
            ]
        },
        {
            "Sid": "AllowAllOperations",
            "Effect": "Allow",
            "Action": [
                "dynamodb:*"
            ],
            "Resource": [
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/CDE_TokenInfo*",
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/CDE_TokenInfo*/*"
            ]
        },
                {
   "Effect": "Allow",
   "Action": [
       "kms:Encrypt",
       "kms:Decrypt",
       "kms:ReEncrypt*",
       "kms:GenerateDataKey*",
       "kms:DescribeKey",
       "kms:CreateGrant" 

   ],
   "Resource": "${aws_kms_key.cde_tokenisation_key.arn}"
}
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

locals {
    services_for_cde_tokenisation_permissions = ["tokenisation-service"]
    service_env_set_for_cde_tokenisation_permissions = [for s in local.service_env_set: s if (contains(local.services_for_cde_tokenisation_permissions, s[1]) && s[0][2] == true)]
}
data "aws_iam_role" "cde_tokenisation_service_role" {
  count = length(local.service_env_set_for_cde_tokenisation_permissions)
  name = "${local.service_env_set_for_cde_tokenisation_permissions[count.index][0][1]}-${local.service_env_set_for_cde_tokenisation_permissions[count.index][0][0]}-${local.service_env_set_for_cde_tokenisation_permissions[count.index][1]}-role"
  depends_on = [ aws_iam_role.service_role ]
}


resource "aws_iam_role_policy_attachment" "attach_cde_tokenisation_permissions_to_service_role" {
  count = length(local.service_env_set_for_cde_tokenisation_permissions)
  role       = data.aws_iam_role.cde_tokenisation_service_role[count.index].name
  policy_arn = aws_iam_policy.cde_tokenisation_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_bank_keys_permissions_to_service_role" {
  count = length(local.service_env_set_for_cde_tokenisation_permissions)
  role       = data.aws_iam_role.cde_tokenisation_service_role[count.index].name
  policy_arn = aws_iam_policy.access_to_bank_keys.arn
}