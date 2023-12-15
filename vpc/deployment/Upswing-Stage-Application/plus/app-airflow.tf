module "airflow_secrets" {
  source = "../../../modules/app_secret/v1"
  name = "airflow-secrets"
  namespace = "airflow"
  secret_keys = ["postgres-password", "gitSshKey", "AIRFLOW__SMTP__SMTP_PASSWORD", "fernet-key", "webserver-secret-key", "connection"]
  secret_binary = module.airflow_secret.secret_binary
}