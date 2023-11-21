resource "aws_iam_policy" "cert_manager_route53_permissions" {
    description = "cert-manager-route53-permissions"
    name        = "cert-manager-route53-permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": "arn:aws:iam::${local.shared_infra_account_id}:role/cert-manager-route53-role",
      "Action": "sts:AssumeRole"
    }
  ]
}
EOT

    tags = merge(local.tags,tomap({"Name" = "cert-manager-route53-permissions"}))
}

locals {
    cert_manager_namespace = "kube-system"
    cert_manager_serviceaccount = "cert-manager-sa"
}

# aws_iam_role.cert_manager_route53_role:
resource "aws_iam_role" "cert_manager_route53_role" {
    assume_role_policy    =  <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${var.account_id}:oidc-provider/${local.oidc_provider_url}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider_url}:aud": "sts.amazonaws.com",
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.cert_manager_namespace}:${local.cert_manager_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "cert-manager-route53-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.cert_manager_route53_permissions.arn}"
    ]
    max_session_duration  = 3600
    name                  = "cert-manager-route53-role"
    path                  = "/"
    tags = merge(local.tags,tomap({"Name" = "cert-manager-route53-role"}))

}

output "cert_manager_route53_role_arn" {
    value = aws_iam_role.cert_manager_route53_role.arn
}
