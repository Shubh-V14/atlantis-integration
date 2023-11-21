module "s3_v1" {
  source = "../../../modules/s3_v1"
  bucket_name = "dump-collector-prod"
  variant = "prod"
  namespace = "in1-system"
  serviceaccount = "dump-collector-sa"
  oidc_provider_url = local.oidc_provider_url
  account_id = var.account_id
}