# aws_iam_role.ups_stage_customer_service_role:
resource "aws_iam_role" "service_role" {
    for_each = local.service_env_map
    assume_role_policy    = <<EOT
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${each.value[0][0]}:${each.value[1]}-sa"

        }
      }
    }
  ]
}
EOT
    description           = "${local.variant}-${each.value[0][0]}-${each.value[1]}-role"
    force_detach_policies = false

    max_session_duration  = 3600
    name                  = "${local.variant}-${each.value[0][0]}-${each.value[1]}-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}
