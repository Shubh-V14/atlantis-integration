locals {
    usw_static_assets_hosting_bucket_name = "usw-static-assets-hosting-stage"
}

resource "aws_cloudfront_response_headers_policy" "set_no_store_cache" {
  name = "set-no-store-cache"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "no-store"
    }
  }
}
module "cloudfront_s3_website_without_domain" {
    source                 = "../../../modules/terraform-aws-cloudfront-s3-website"
    domain_name            = "usw-static-assets-hosting-stage" // Any random identifier for s3 bucket name
    use_default_domain     = true
    upload_sample_file     = false
    cloudfront_geo_restriction_locations = ["IN"]
    cloudfront_max_ttl = 300
    response_headers_policy_id = aws_cloudfront_response_headers_policy.set_no_store_cache.id
}

output "cloudfront_domain_name" {
    value = module.cloudfront_s3_website_without_domain.cloudfront_domain_name
}

output "cloudfront_bucket_arn" {
    value = module.cloudfront_s3_website_without_domain.s3_bucket_arn
}
# aws_iam_policy.usw_static_assets_hosting_policy:
resource "aws_iam_policy" "usw_static_assets_hosting_policy" {
    description = "${local.usw_static_assets_hosting_bucket_name}-permissions"
    name        = "${local.usw_static_assets_hosting_bucket_name}-permissions"
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
            "${module.cloudfront_s3_website_without_domain.s3_bucket_arn}/*",
            "${module.cloudfront_s3_website_without_domain.s3_bucket_arn}"
            ]
        }

    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

# aws_iam_role.idp_role:
resource "aws_iam_role" "usw_static_assets_hosting_role" {
      assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Condition = {}
                    Effect    = "Allow"
                    Principal = {
                        AWS = "arn:aws:iam::537885521837:root"
                    }
                },
            ]
            Version   = "2012-10-17"
        }
    )
    description           = "usw-static-assets-hosting-stage"
    force_detach_policies = false
    managed_policy_arns   = [
        aws_iam_policy.usw_static_assets_hosting_policy.arn
    ]
    max_session_duration  = 3600
    name                  = "usw-static-assets-hosting-stage"
    path                  = "/"
    tags                  = {}
    tags_all              = {}
}

output "usw_static_assets_hosting_role" {
    value = aws_iam_role.usw_static_assets_hosting_role.arn
}

resource "aws_s3_bucket_cors_configuration" "set_cors" {
  bucket = module.cloudfront_s3_website_without_domain.s3_bucket_name

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
  }
}
