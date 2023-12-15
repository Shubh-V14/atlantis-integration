resource "aws_s3_bucket" "ups_uat_teleport" {
    bucket                      = "ups-uat-teleport"
    object_lock_enabled         = false
    tags_all                    = {}

    tags = merge(local.tags,tomap({"Name" = "ups-uat-teleport"}))
}

resource "aws_s3_bucket_versioning" "ups_uat_teleport" {
  bucket = aws_s3_bucket.ups_uat_teleport.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_kms_key" "uat_teleport_storage_key" {
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

   tags = merge(local.tags,tomap({"Name" = "teleport-storage"}))
}

output "uat_teleport_storage_key_arn" {
  value = aws_kms_key.uat_teleport_storage_key.arn
}

resource "aws_kms_alias" "uat_teleport_storage_key_alias" {
  name          = "alias/uat_teleport_storage"
  target_key_id = aws_kms_key.uat_teleport_storage_key.id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "uat_teleport_storage" {
    bucket = aws_s3_bucket.ups_uat_teleport.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.uat_teleport_storage_key.id
        }
    }
    depends_on = [
        aws_kms_key.uat_teleport_storage_key
    ]
}



# aws_iam_policy.ups_uat_teleport_policy:
resource "aws_iam_policy" "ups_uat_teleport_policy" {
    description = "ups-uat-teleport-s3-permissions"
    name        = "ups-uat-teleport-s3-permissions"
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
            "Resource": "arn:aws:s3:::ups-uat-teleport"
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
            "Resource": "arn:aws:s3:::ups-uat-teleport/*"
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

  tags = merge(local.tags,tomap({"Name" = "ups-uat-teleport-policy"}))
}


locals {
    ups_uat_teleport_namespace = "teleport"
    ups_uat_teleport_serviceaccount = "teleport"
}

# aws_iam_role.ups_uat_teleport_role:
resource "aws_iam_role" "ups_uat_teleport_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_uat_teleport_namespace}:${local.ups_uat_teleport_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups-uat-teleport-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_uat_teleport_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-uat-teleport-role"
    path                  = "/"

    tags = merge(local.tags,tomap({"Name" = "ups-uat-teleport-role"}))

}

output "ups_uat_teleport_s3_role_arn" {
    value = aws_iam_role.ups_uat_teleport_role.arn
}