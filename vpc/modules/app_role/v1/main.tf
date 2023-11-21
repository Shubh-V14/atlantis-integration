variable variant {}
variable iam_policy {
  default = ""
}
variable oidc_provider_url {}
variable oidc_provider_arn {}
variable name {}
variable namespace {}
variable serviceaccount {}
variable tags {}
variable account_id {}
variable iam_policy_attachments {
  type = list(string)
  default = []
}

# aws_iam_policy.upswing_stage_grafana_policy:
resource "aws_iam_policy" "app_policy" {
    count = var.iam_policy != "" ? 1: 0
    description = "upswing-${var.variant}-${var.name}-permissions"
    name        = "upswing-${var.variant}-${var.name}-permissions"
    policy      = var.iam_policy

    tags = merge(var.tags,tomap({"Name" = "upswing-${var.variant}-${var.name}-policy"}))
}

resource "aws_iam_role" "app_role" {
    assume_role_policy    = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${var.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${var.oidc_provider_url}:aud": "sts.amazonaws.com",
          "${var.oidc_provider_url}:sub": "system:serviceaccount:${var.namespace}:${var.serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "upswing-${var.variant}-${var.name}-role"
    force_detach_policies = false
    max_session_duration  = 3600
    name                  = "upswing-${var.variant}-${var.name}-role"
    path                  = "/"

    tags = merge(var.tags,tomap({"Name" = "upswing-${var.variant}-${var.name}-role"}))

}

resource "aws_iam_role_policy_attachment" "main" {
  count = var.iam_policy != "" ? 1: 0
  role = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "additional" {
  count = length(var.iam_policy_attachments)
  role = aws_iam_role.app_role.name
  policy_arn = var.iam_policy_attachments[count.index]
}

output "role_arn" {
    value = aws_iam_role.app_role.arn
}
