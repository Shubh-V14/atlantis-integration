locals {
    discourse_namespace = "discourse"
    discourse_serviceaccount = "discourse"
}

# aws_iam_role.discourse_role:
resource "aws_iam_role" "discourse_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.discourse_namespace}:${local.discourse_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "discourse-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ses_permissions.arn}"
    ]
    max_session_duration  = 3600
    name                  = "discourse-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "discourse_role_arn" {
    value = aws_iam_role.discourse_role.arn
}

