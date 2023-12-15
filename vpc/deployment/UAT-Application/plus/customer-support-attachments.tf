locals {
    customer_support_attachments_bucket_name = "customer-support-attachments-uat"
}

resource "aws_s3_bucket" "customer_support_attachments" {
    bucket                      = local.customer_support_attachments_bucket_name
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}
}

output "customer_support_attachments" {
    value = aws_s3_bucket.customer_support_attachments.arn
}

resource "aws_s3_bucket_ownership_controls" "customer_support_attachments" {
  bucket = aws_s3_bucket.customer_support_attachments.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_versioning" "customer_support_attachments" {
  bucket = aws_s3_bucket.customer_support_attachments.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "customer_support_attachments" {
    bucket = aws_s3_bucket.customer_support_attachments.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}


# aws_iam_policy.customer_support_attachments_policy:
resource "aws_iam_policy" "customer_support_attachments_policy" {
    description = "${local.customer_support_attachments_bucket_name}-permissions"
    name        = "${local.customer_support_attachments_bucket_name}-permissions"
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
            "${aws_s3_bucket.customer_support_attachments.arn}/*",
            "${aws_s3_bucket.customer_support_attachments.arn}"
            ]
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


locals {
    services_for_customer_support_permissions = ["customer-support-service"]
    service_env_set_for_customer_support_permissions = [for s in local.service_env_set: s if contains(local.services_for_customer_support_permissions, s[1])]
}
data "aws_iam_role" "customer_support_service_role" {
  count = length(local.service_env_set_for_customer_support_permissions)
  name = "${local.service_env_set_for_customer_support_permissions[count.index][0][1]}-${local.service_env_set_for_customer_support_permissions[count.index][0][0]}-${local.service_env_set_for_customer_support_permissions[count.index][1]}-role"
  depends_on = [ aws_iam_role.service_role ]
}

resource "aws_iam_role_policy_attachment" "attach_customer_support_permissions_to_service_role" {
  count = length(local.service_env_set_for_customer_support_permissions)
  role       = data.aws_iam_role.customer_support_service_role[count.index].name
  policy_arn = aws_iam_policy.customer_support_attachments_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_tratev_permissions_to_customer_support_service_role" {
  count = length(local.service_env_set_for_customer_support_permissions)
  role       = data.aws_iam_role.customer_support_service_role[count.index].name
  policy_arn = module.s3_trat_ev.iam_policy_arn
}