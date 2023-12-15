module "dump_collector_s3" {
  source = "../../../modules/s3_v3"
  bucket_name = "upswing-stage-dump-collector"
  expiry = {"enabled": true, "days": 3}
}


module "dump_collector_role" {
  source = "../../../modules/app_role/v1"
  name = "dump-collector"
  namespace = "alpha-system"
  serviceaccount = "dump-collector-sa"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id
  iam_policy_attachments = [module.dump_collector_s3.iam_policy_arn]
}

output "dump_collector_role" {
  value = module.dump_collector_role.role_arn
}