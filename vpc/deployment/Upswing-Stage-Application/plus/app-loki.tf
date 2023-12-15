#Used for temporary storage via customer service
module "loki_s3_bucket" {
  source = "../../../modules/s3_v3"
  bucket_name = "upswing-${local.variant}-loki"
  expiry = {"enabled": true, "days": 180}
}

module "loki_role" {
  source = "../../../modules/app_role/v1"
  name = "loki"
  namespace = "loki"
  serviceaccount = "loki"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id
  #Pass iam_policy attachment separtely
  iam_policy      = <<EOT
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
                "${module.loki_s3_bucket.bucket_arn}/*",
                "${module.loki_s3_bucket.bucket_arn}"
            ]
        }

    ]
}
EOT
}

output "loki_role_arn" {
    value = module.loki_role.role_arn
}

output "loki_bucket_arn" {
  value = module.loki_s3_bucket.bucket_arn
}