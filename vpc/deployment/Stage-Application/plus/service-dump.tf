locals {
    service_dump_bucket_name = "service-dump-stage"
}

resource "aws_s3_bucket" "service_dump" {
    bucket                      = local.service_dump_bucket_name
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}
}

output "service_dump" {
    value = aws_s3_bucket.service_dump.arn
}

resource "aws_s3_bucket_ownership_controls" "service_dump" {
  bucket = aws_s3_bucket.service_dump.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_versioning" "service_dump" {
  bucket = aws_s3_bucket.service_dump.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "service_dump" {
    bucket = aws_s3_bucket.service_dump.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}


# aws_iam_policy.service_dump_policy:
resource "aws_iam_policy" "service_dump_policy" {
    description = "${local.service_dump_bucket_name}-permissions"
    name        = "${local.service_dump_bucket_name}-permissions"
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
            "${aws_s3_bucket.service_dump.arn}/*",
            "${aws_s3_bucket.service_dump.arn}"
            ]
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

locals {
    service_env_set_with_all_props_for_service_dump_permissions = [for s in local.service_env_set_with_all_props: s if try(s[1].type, "") != "node"]
}
data "aws_iam_role" "service_dump_service_role" {
  count = length(local.service_env_set_with_all_props_for_service_dump_permissions)
  name = "${local.service_env_set_with_all_props_for_service_dump_permissions[count.index][0][1]}-${local.service_env_set_with_all_props_for_service_dump_permissions[count.index][0][0]}-${local.service_env_set_with_all_props_for_service_dump_permissions[count.index][1].name}-role"
  depends_on = [ aws_iam_role.service_role ]
}

resource "aws_iam_role_policy_attachment" "attach_service_dump_permissions_to_service_role" {
  count = length(local.service_env_set_with_all_props_for_service_dump_permissions)
  role       = data.aws_iam_role.service_dump_service_role[count.index].name
  policy_arn = aws_iam_policy.service_dump_policy.arn
}
