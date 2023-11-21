locals {
    usw_static_assets_hosting_bucket_prefix = "usw-sah"
    usw_static_assets_hosting_bucket_name = "upswing-${local.variant}-${local.usw_static_assets_hosting_bucket_prefix}"
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
    domain_name            = local.usw_static_assets_hosting_bucket_name // Any random identifier for s3 bucket name
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

resource "aws_s3_bucket_cors_configuration" "set_cors" {
  bucket = module.cloudfront_s3_website_without_domain.s3_bucket_name

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
  }
}
