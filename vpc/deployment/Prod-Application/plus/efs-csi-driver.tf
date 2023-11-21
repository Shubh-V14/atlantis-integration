resource "aws_iam_policy" "efs_csi_driver_permissions" {
    description = "efs-csi-driver-permissions"
    name        = "efs-csi-driver-permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:DescribeMountTargets",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:TagResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
EOT
    tags        = {}
    tags_all    = {}
}

locals {
    efs_csi_driver_namespace = "kube-system"
    efs_csi_driver_serviceaccount = "efs-csi-controller-sa"
}

# aws_iam_role.efs_csi_driver_role:
resource "aws_iam_role" "efs_csi_driver_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.efs_csi_driver_namespace}:${local.efs_csi_driver_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "efs-csi-driver-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.efs_csi_driver_permissions.arn}"
    ]
    max_session_duration  = 3600
    name                  = "efs-csi-driver-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "efs_csi_driver_role_arn" {
    value = aws_iam_role.efs_csi_driver_role.arn
}