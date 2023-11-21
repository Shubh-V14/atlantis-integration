module "secret_encryption_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "Customer managed key to encrypt secrets in aws secret manager"

  # Policy
  key_administrators = [
    "arn:aws:iam::${var.account_id}:root"
  ]

  # Aliases
  aliases = ["secret-encryption"]

  tags = local.tags
}

variable "argocd_secrets" {
  type = map(string)
  default = {}
}

variable "vault_secrets" {
  type = map(string)
  default = {}
}

variable "grafana_secrets" {
  type = map(string)
  default = {}
}

variable "keycloak_secrets" {
  type = map(string)
  default = {}
}

variable "jenkins_secrets" {
  type = map(string)
  default = {}
}

variable "airflow_secrets" {
  type = map(string)
  default = {}
}

variable "dante_secrets" {
  type = map(string)
  default = {}
}

module "argocd_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "argocd"
  variant = local.variant
  secrets = var.argocd_secrets
  kms_key_id = module.secret_encryption_key.key_id
}

module "vault_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "vault"
  variant = local.variant
  secrets = var.vault_secrets
  kms_key_id = module.secret_encryption_key.key_id
}

module "grafana_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "grafana"
  variant = local.variant
  secrets = var.grafana_secrets
  kms_key_id = module.secret_encryption_key.key_id
}

module "keycloak_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "keycloak"
  variant = local.variant
  secrets = var.keycloak_secrets
  kms_key_id = module.secret_encryption_key.key_id
}

module "jenkins_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "jenkins"
  variant = local.variant
  secrets = var.jenkins_secrets
  kms_key_id = module.secret_encryption_key.key_id
}


resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
}

resource "kubernetes_namespace" "dante" {
  metadata {
    name = "dante"
  }
}


module "airflow_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "airflow"
  variant = local.variant
  secrets = var.airflow_secrets
  kms_key_id = module.secret_encryption_key.key_id
}

module "dante_secret" {
  source = "../../../modules/secret/seed_update/v1"
  name = "dante"
  variant = local.variant
  secrets = var.dante_secrets
  kms_key_id = module.secret_encryption_key.key_id
}
