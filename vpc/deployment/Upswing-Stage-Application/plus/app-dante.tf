module "dante_secrets" {
  source = "../../../modules/app_secret/v1"
  name = "dante-secrets"
  namespace = "cde-alpha"
  secret_keys = ["username", "password" ]
  secret_binary = module.dante_secret.secret_binary
}
