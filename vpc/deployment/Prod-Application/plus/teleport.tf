resource "aws_s3_bucket" "ups_prod_teleport" {
    bucket                      = "ups-prod-teleport"
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}


}

resource "aws_s3_bucket_versioning" "ups_prod_teleport" {
  bucket = aws_s3_bucket.ups_prod_teleport.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_kms_key" "prod_teleport_storage_key" {
  description             = "Key for encrypting teleport s3 storage"
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
      Name        = "teleport-storage"
    }
}

output "prod_teleport_storage_key_arn" {
  value = aws_kms_key.prod_teleport_storage_key.arn
}

resource "aws_kms_alias" "prod_teleport_storage_key_alias" {
  name          = "alias/prod_teleport_storage"
  target_key_id = aws_kms_key.prod_teleport_storage_key.id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "prod_teleport_storage" {
    bucket = aws_s3_bucket.ups_prod_teleport.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.prod_teleport_storage_key.id
        }
    }
    depends_on = [
        aws_kms_key.prod_teleport_storage_key
    ]
}



# aws_iam_policy.ups_prod_teleport_policy:
resource "aws_iam_policy" "ups_prod_teleport_policy" {
    description = "ups-prod-teleport-s3-permissions"
    name        = "ups-prod-teleport-s3-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
      {
            "Sid": "BucketActions",
            "Effect": "Allow",
            "Action": [
                "s3:PutEncryptionConfiguration",
                "s3:PutBucketVersioning",
                "s3:ListBucketVersions",
                "s3:ListBucketMultipartUploads",
                "s3:ListBucket",
                "s3:GetEncryptionConfiguration",
                "s3:GetBucketVersioning",
                "s3:CreateBucket"
            ],
            "Resource": "arn:aws:s3:::ups-prod-teleport"
        },
        {
            "Sid": "ObjectActions",
            "Effect": "Allow",
            "Action": [
                "s3:GetObjectVersion",
                "s3:GetObjectRetention",
                "s3:*Object",
                "s3:ListMultipartUploadParts",
                "s3:AbortMultipartUpload"
            ],
            "Resource": "arn:aws:s3:::ups-prod-teleport/*"
        },
              {
            "Sid": "ClusterStateStorage",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchWriteItem",
                "dynamodb:UpdateTimeToLive",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:DescribeStream",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:CreateTable",
                "dynamodb:DescribeTable",
                "dynamodb:GetShardIterator",
                "dynamodb:GetItem",
                "dynamodb:UpdateTable",
                "dynamodb:GetRecords",
                "dynamodb:UpdateContinuousBackups"
            ],
            "Resource": [
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/teleport-backend",
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/teleport-backend/stream/*"
            ]
        },
           {
            "Sid": "ClusterEventsStorage",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateTable",
                "dynamodb:BatchWriteItem",
                "dynamodb:UpdateTimeToLive",
                "dynamodb:PutItem",
                "dynamodb:DescribeTable",
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:UpdateItem",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:UpdateTable",
                "dynamodb:UpdateContinuousBackups"
            ],
            "Resource": [
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/teleport-events",
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/teleport-events/index/*"
            ]
        },
         {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:ModifyDBInstance",
                "rds:DescribeDBClusters",
                "rds:ModifyDBCluster",
                "rds-db:connect"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:GetUserPolicy",
                "iam:PutUserPolicy",
                "iam:DeleteUserPolicy"
            ],
            "Resource": [
                "arn:aws:iam::*:user/*"
            ]
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


locals {
    ups_prod_teleport_namespace = "teleport"
    ups_prod_teleport_serviceaccount = "teleport"
}

# aws_iam_role.ups_prod_teleport_role:
resource "aws_iam_role" "ups_prod_teleport_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_prod_teleport_namespace}:${local.ups_prod_teleport_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups-prod-teleport-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_prod_teleport_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-prod-teleport-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_prod_teleport_s3_role_arn" {
    value = aws_iam_role.ups_prod_teleport_role.arn
}