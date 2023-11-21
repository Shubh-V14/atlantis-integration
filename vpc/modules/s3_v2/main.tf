locals {
    bucket_name = var.bucket_name
    expiry_days = var.expiry_days
    versioning = var.versioning
}

variable "bucket_name" {
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
