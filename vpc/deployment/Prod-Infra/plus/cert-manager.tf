resource "aws_iam_policy" "cert_manager_route53_policy" {
    description = "cert_manager_route53_permissions"
    name        = "cert_manager_route53_permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
EOT

    tags = merge(local.tags,tomap({"Name" = "cert-manager-route53-permissions"}))
}

resource "aws_iam_role" "cert_manager_route53_role" {
    assume_role_policy    =  <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${local.prod_application_account_id}"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOT
    description           = "cert-manager-route53-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.cert_manager_route53_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "cert-manager-route53-role"
    path                  = "/"
    tags = merge(local.tags,tomap({"Name" = "cert-manager-route53-role"}))

}

output "cert_manager_route53_role_arn" {
    value = aws_iam_role.cert_manager_route53_role.arn
}