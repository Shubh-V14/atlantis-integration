module "cert_manager_role" {
  source = "../../../modules/app_role/v1"
  name = "cert-manager"
  namespace = "kube-system"
  serviceaccount = "cert-manager-sa"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id
  iam_policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": "arn:aws:iam::776633114724:role/cert-manager-route53-role",
      "Action": "sts:AssumeRole"
    }
  ]
}
EOT
}

output "cert_manager_role_arn" {
    value = module.cert_manager_role.role_arn
}
