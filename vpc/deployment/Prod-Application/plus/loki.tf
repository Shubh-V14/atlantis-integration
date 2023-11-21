resource "aws_s3_bucket" "ups_prod_loki" {
    bucket                      = "ups-prod-loki"
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}


}

resource "aws_s3_bucket_versioning" "ups_prod_loki" {
  bucket = aws_s3_bucket.ups_prod_loki.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_kms_key" "prod_loki_storage_key" {
  description             = "Key for encrypting loki storage s3"
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
      Environment = "Prod"
      Name        = "loki-storage"
    }
}

output "prod_loki_storage_key_arn" {
  value = aws_kms_key.prod_loki_storage_key.arn
}

resource "aws_kms_alias" "prod_loki_storage_key_alias" {
  name          = "alias/prod_loki_storage"
  target_key_id = aws_kms_key.prod_loki_storage_key.id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "prod_loki_storage" {
    bucket = aws_s3_bucket.ups_prod_loki.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.prod_loki_storage_key.arn
        }
    }
    depends_on = [
        aws_kms_key.prod_loki_storage_key
    ]
}



# aws_iam_policy.ups_prod_loki_policy:
resource "aws_iam_policy" "ups_prod_loki_policy" {
    description = "ups_prod_loki s3 permissions"
    name        = "ups-prod-loki-s3-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListObjects"
            ],
            "Resource": [
                "arn:aws:s3:::ups-prod-loki/*",
                "arn:aws:s3:::ups-prod-loki"
            ]
        },

        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
               "kms:GenerateDataKey",
               "kms:Decrypt"

            ],
            "Resource": [
                "${aws_kms_key.prod_loki_storage_key.arn}"
            ]
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


locals {
    ups_prod_loki_namespace = "loki"
    ups_prod_loki_serviceaccount = "loki"
}

# aws_iam_role.ups_prod_loki_role:
resource "aws_iam_role" "ups_prod_loki_role" {
    assume_role_policy    = <<EOT
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_prod_loki_namespace}:${local.ups_prod_loki_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups_prod_loki-s3-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_prod_loki_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-prod-loki-s3-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_prod_loki_s3_role_arn" {
    value = aws_iam_role.ups_prod_loki_role.arn
}