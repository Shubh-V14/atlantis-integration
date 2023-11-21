locals {
  mimir_buckets = ["storage", "am-storage", "ruler-storage"]
}
#Used for temporary storage via customer service
module "mimir_s3_buckets" {
  count = length(local.mimir_buckets)
  source = "../../../modules/s3_v3"
  bucket_name = "upswing-${local.variant}-mimir-${local.mimir_buckets[count.index]}"
  expiry = {"enabled": true, "days": 180}
}

module "mimir_role" {
  source = "../../../modules/app_role/v1"
  name = "mimir"
  namespace = "mimir"
  serviceaccount = "mimir-distributed"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id
  iam_policy_attachments =  module.mimir_s3_buckets[*].iam_policy_arn
}

output "mimir_role_arn" {
    value = module.mimir_role.role_arn
}

output "mimir_bucket_arns" {
  value = module.mimir_s3_buckets[*].bucket_arn
}