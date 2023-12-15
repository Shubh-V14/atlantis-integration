locals {
    bucket_name = var.bucket_name
    variant = var.variant
    namespace = var.namespace
    serviceaccount = var.serviceaccount
    oidc_provider_url = var.oidc_provider_url
    account_id = var.account_id
    expiry_days = var.expiry_days
    versioning = var.versioning
}

variable "bucket_name" {
  type = string
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

variable "expiry_days" {
  type = number
  default = 14
}

variable "versioning" {
  type = string
  default = "Suspended"
}

resource "aws_s3_bucket" "upswing_bucket" {
    bucket                      = local.bucket_name
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}
}

output "bucket_arn" {
    value = aws_s3_bucket.upswing_bucket.arn
}

output "bucket_id" {
  value = aws_s3_bucket.upswing_bucket.id
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.upswing_bucket.bucket_regional_domain_name
}

resource "aws_s3_bucket_ownership_controls" "upswing_bucket" {
  bucket = aws_s3_bucket.upswing_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_versioning" "upswing_bucket" {
  bucket = aws_s3_bucket.upswing_bucket.id
  versioning_configuration {
        status = "${local.versioning}"
    }
}

resource "aws_s3_bucket_lifecycle_configuration" "expire" {
  rule {
    id      = "expire"
    status  = "Enabled"

    expiration {
      days = local.expiry_days
    }
  }

  bucket = aws_s3_bucket.upswing_bucket.id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "upswing_bucket" {
    bucket = aws_s3_bucket.upswing_bucket.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}


# aws_iam_policy.upswing_bucket_policy:
resource "aws_iam_policy" "upswing_bucket_policy" {
    description = "${local.bucket_name}-permissions"
    name        = "${local.bucket_name}-permissions"
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
            "Resource": [
            "${aws_s3_bucket.upswing_bucket.arn}/*",
            "${aws_s3_bucket.upswing_bucket.arn}"
            ]
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

output "iam_policy_arn" {
  value = aws_iam_policy.upswing_bucket_policy.arn
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
    description           = "${local.variant}-${local.namespace}-${local.bucket_name}-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.upswing_bucket_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "${local.variant}-${local.namespace}-${local.bucket_name}-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}


output "upswing_bucket_role" {
    value = aws_iam_role.bucket_role.arn
}
