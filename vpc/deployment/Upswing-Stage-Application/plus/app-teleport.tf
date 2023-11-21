#Used for temporary storage via customer service
module "teleport_s3_bucket" {
  source = "../../../modules/s3_v3"
  bucket_name = "upswing-${local.variant}-teleport"
  expiry = {"enabled": false}
}

module "teleport_role" {
  source = "../../../modules/app_role/v1"
  name = "teleport"
  namespace = "teleport"
  serviceaccount = "teleport"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id
  iam_policy      = <<EOT
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
                "s3:GetBucketVersioning"
            ],
            "Resource": "${module.teleport_s3_bucket.bucket_arn}"
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
            "Resource": "${module.teleport_s3_bucket.bucket_arn}/*"
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
        }
    ]
  }
EOT
}

output "teleport_role" {
  value = module.teleport_role.role_arn
}