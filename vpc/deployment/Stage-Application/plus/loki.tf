resource "aws_s3_bucket" "ups-stage-loki" {
    bucket                      = "ups-stage-loki"
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}


}

resource "aws_s3_bucket_versioning" "ups-stage-loki" {
  bucket = aws_s3_bucket.ups-stage-loki.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ups-stage-loki" {
    bucket = aws_s3_bucket.ups-stage-loki.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}


# aws_iam_policy.ups_stage_loki_policy:
resource "aws_iam_policy" "ups_stage_loki_policy" {
    description = "ups-stage-loki-s3-permissions"
    name        = "ups-stage-loki-s3-permissions"
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
                "arn:aws:s3:::ups-stage-loki/*",
            "arn:aws:s3:::ups-stage-loki"
            ]
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


locals {
    ups_stage_loki_namespace = "loki"
    ups_stage_loki_serviceaccount = "loki"
}

# aws_iam_role.ups_stage_loki_role:
resource "aws_iam_role" "ups_stage_loki_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_stage_loki_namespace}:${local.ups_stage_loki_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups-stage-loki-s3-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_stage_loki_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-stage-loki-s3-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_stage_loki_s3_role_arn" {
    value = aws_iam_role.ups_stage_loki_role.arn
}