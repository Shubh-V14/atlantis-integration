module "s3_v1" {
  source = "../../../modules/s3_v1"
  bucket_name = "dump-collector-stage"
  variant = "stage"
  namespace = "alpha-system"
  serviceaccount = "dump-collector-sa"
  oidc_provider_url = local.oidc_provider_url
  account_id = var.account_id
}