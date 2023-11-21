module "mimir_storage" {
  source = "../../../modules/s3"
  bucket_names = ["ups-mimir-storage-uat", "ups-mimir-am-storage-uat", "ups-mimir-ruler-storage-uat"]
  variant = "uat"
  namespace = "mimir"
  serviceaccount = "mimir-distributed"
  oidc_provider_url = local.oidc_provider_url
  account_id = var.account_id
  expiry_days = 390
  versioning = "Suspended"
}
