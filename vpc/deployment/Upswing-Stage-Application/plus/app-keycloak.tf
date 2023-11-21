module "keycloak_secrets" {
  source = "../../../modules/app_secret/v1"
  name = "keycloak-secrets"
  namespace = "keycloak"
  secret_keys = ["postgres-password"]
  secret_binary = module.keycloak_secret.secret_binary
}