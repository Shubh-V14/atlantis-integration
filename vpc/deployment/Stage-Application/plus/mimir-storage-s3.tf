module "mimir_storage" {
  source = "../../../modules/s3"
  bucket_names = ["ups-mimir-storage-stage", "ups-mimir-am-storage-stage", "ups-mimir-ruler-storage-stage"]
  variant = "stage"
  namespace = "mimir"
  serviceaccount = "mimir-distributed"
  oidc_provider_url = local.oidc_provider_url
  account_id = var.account_id
  expiry_days = 390
  versioning = "Suspended"
}
