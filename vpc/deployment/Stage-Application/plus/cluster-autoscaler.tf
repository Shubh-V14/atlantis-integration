resource "aws_iam_policy" "cluster_autoscaler_permissions" {
    description = "cluster-autoscaler-permissions"
    name        = "cluster-autoscaler-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/k8s.io/cluster-autoscaler/stage-application1": "owned"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeAutoScalingGroups",
                "ec2:DescribeLaunchTemplateVersions",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeInstances",
                "ec2:DescribeInstanceTypes"
            ],
            "Resource": "*"
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

locals {
    cluster_autoscaler_namespace = "kube-system"
    cluster_autoscaler_serviceaccount = "cluster-autoscaler"
}

# aws_iam_role.cluster_autoscaler_role:
resource "aws_iam_role" "cluster_autoscaler_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.cluster_autoscaler_namespace}:${local.cluster_autoscaler_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "cluster-autoscaler-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.cluster_autoscaler_permissions.arn}"
    ]
    max_session_duration  = 3600
    name                  = "cluster-autoscaler-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "cluster_autoscaler_role_arn" {
    value = aws_iam_role.cluster_autoscaler_role.arn
}