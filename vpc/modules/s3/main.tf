#Module to provide access to a service account to multiple buckets
locals {
    bucket_names = var.bucket_names
    variant = var.variant
    namespace = var.namespace
    serviceaccount = var.serviceaccount
    oidc_provider_url = var.oidc_provider_url
    account_id = var.account_id
    expiry_days = var.expiry_days
    versioning = var.versioning
}

variable "bucket_names" {
  type = list(string)
}

variable "variant" {
  type = string
}

variable "namespace" {
  type = string
}

variable "serviceaccount" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "account_id" {
  type = string
}

variable "versioning" {
  type = string
  default = "Suspended"
}

variable "expiry_days" {
  type = number
  default = 0
}

resource "aws_s3_bucket" "upswing_buckets" {
    count = length(local.bucket_names)
    bucket                      = local.bucket_names[count.index]
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}
}

output "bucket_arns" {
    value = aws_s3_bucket.upswing_buckets[*].arn
}

resource "aws_s3_bucket_lifecycle_configuration" "expire" {
  count = local.expiry_days != 0 ? length(local.bucket_names) : 0
  rule {
    id      = "expire"
    status  = "Enabled"

    expiration {
      days = local.expiry_days
    }
  }

  bucket = aws_s3_bucket.upswing_buckets[count.index].id
}

resource "aws_s3_bucket_ownership_controls" "upswing_buckets" {
  count = length(local.bucket_names)
  bucket = aws_s3_bucket.upswing_buckets[count.index].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_versioning" "upswing_buckets" {
  count = length(local.bucket_names)
  bucket = aws_s3_bucket.upswing_buckets[count.index].id
  versioning_configuration {
        status = "${local.versioning}"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "upswing_buckets" {
    count = length(local.bucket_names)
    bucket = aws_s3_bucket.upswing_buckets[count.index].id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

locals {
  permission_resources = flatten([for b in aws_s3_bucket.upswing_buckets: ["${b.arn}", "${b.arn}/*"] ])
}

# aws_iam_policy.upswing_bucket_policy:
resource "aws_iam_policy" "upswing_bucket_policy" {
    description = "${local.variant}-${local.namespace}-${local.serviceaccount}-bucket-permissions"
    name        = "${local.variant}-${local.namespace}-${local.serviceaccount}-bucket-permissions"
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
                "s3:ListObjects",
                "s3:ListObjectsV2"
            ],
            "Resource": ${jsonencode(local.permission_resources)}
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

resource "aws_iam_role" "bucket_role" {
    assume_role_policy    = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_provider_url}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider_url}:aud": "sts.amazonaws.com",
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.namespace}:${local.serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "${local.variant}-${local.namespace}-${local.serviceaccount}-bucket-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.upswing_bucket_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "${local.variant}-${local.namespace}-${local.serviceaccount}-bucket-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}


output "upswing_bucket_role" {
    value = aws_iam_role.bucket_role.arn
}
