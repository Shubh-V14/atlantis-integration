#Used for temporary storage via customer service
module "s3_trat_ev" {
  source = "../../../modules/s3_v1"
  bucket_name = "trat-ev"
  variant = "stage"
  namespace = "alpha"
  serviceaccount = "customer-service-sa"
  oidc_provider_url = local.oidc_provider_url
  account_id = var.account_id
  expiry_days =  1
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = module.s3_trat_ev.bucket_id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json

}


data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid = "1"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${local.domain_name}/*",
    ]

    principals {
      type = "AWS"

      identifiers = [
        aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn,
      ]
    }
  }
}


variable "cache_policy_id" {
  description = "cache policy id"
  default = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
}

variable "origin_request_policy_id" {
  default = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  description = "cache policy id"
}

variable "response_headers_policy_id" {
  default = "60669652-455b-4ae9-85a4-c4c02393f86c"
  description = "response header policy id"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags for all the resources, if any"
}

variable "hosted_zone" {
  default     = null
  description = "Route53 hosted zone"
}

variable "acm_certificate_domain" {
  default     = null
  description = "Domain of the ACM certificate"
}

variable "price_class" {
  default     = "PriceClass_100" // Only US,Canada,Europe
  description = "CloudFront distribution price class"
}

variable "use_default_domain" {
  default     = false
  description = "Use CloudFront website address without Route53 and ACM certificate"
}

variable "upload_sample_file" {
  default     = false
  description = "Upload sample html file to s3 bucket"
}

# All values for the TTL are important when uploading static content that changes
# https://stackoverflow.com/questions/67845341/cloudfront-s3-etag-possible-for-cloudfront-to-send-updated-s3-object-before-t
variable "cloudfront_min_ttl" {
  default     = 0
  description = "The minimum TTL for the cloudfront cache"
}

variable "cloudfront_default_ttl" {
  default     = 86400
  description = "The default TTL for the cloudfront cache"
}

variable "cloudfront_max_ttl" {
  default     = 31536000
  description = "The maximum TTL for the cloudfront cache"
}


locals {
  default_certs = var.use_default_domain ? ["default"] : []
  acm_certs     = var.use_default_domain ? [] : ["acm"]
  domain_name   = "trat-ev"
}

locals {
    cloudfront_geo_restriction_locations = ["IN"]
    cloudfront_max_ttl = 300
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    module.s3_trat_ev
  ]

  origin {
    domain_name = module.s3_trat_ev.bucket_regional_domain_name
    origin_id   = "s3-cloudfront"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = []

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = "s3-cloudfront"

    viewer_protocol_policy = "redirect-to-https"

    # https://stackoverflow.com/questions/67845341/cloudfront-s3-etag-possible-for-cloudfront-to-send-updated-s3-object-before-t
    cache_policy_id = var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id
    response_headers_policy_id = var.response_headers_policy_id
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = local.cloudfront_geo_restriction_locations
    }
  }
  dynamic "viewer_certificate" {
    for_each = ["default"]
    content {
      cloudfront_default_certificate = true
    }
  }

  # dynamic "viewer_certificate" {
  #   for_each = local.acm_certs
  #   content {
  #     acm_certificate_arn      = data.aws_acm_certificate.acm_cert[0].arn
  #     ssl_support_method       = "sni-only"
  #     minimum_protocol_version = "TLSv1"
  #   }
  # }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    error_caching_min_ttl = 0
    response_page_path    = "/index.html"
  }

  wait_for_deployment = false
  tags                = var.tags
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${local.domain_name}.s3.amazonaws.com"
}

output "s3_trat_ev_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}