module "jenkins_secrets" {
  source = "../../../modules/app_secret/v1"
  name = "jenkins-secrets"
  namespace = "jenkins"
  secret_keys = ["git", "pat", "OIC_AUTH_CLIENT_SECRET", "vault_token", "admin_user", "admin_password"]
  secret_binary = module.jenkins_secret.secret_binary
}