# aws_iam_policy.jenkins_pipeline_policy:
resource "aws_iam_policy" "uat_jenkins_policy" {
    description = "jenkins-permissions"
    name        = "jenkins-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GetAuthorizationToken",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowPushPull",
            "Effect": "Allow",
            "Action": [
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:CompleteLayerUpload",
                "ecr:GetDownloadUrlForLayer",
                "ecr:InitiateLayerUpload",
                "ecr:PutImage",
                "ecr:UploadLayerPart",
                "ecr:DescribeImages"
            ],
            "Resource": "arn:aws:ecr:ap-south-1:776633114724:repository/*"
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

locals {
    uat_jenkins_namespace = "jenkins"
    uat_jenkins_serviceaccount = "jenkins"
}

# aws_iam_role.uat_jenkins_role:
resource "aws_iam_role" "uat_jenkins_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.uat_jenkins_namespace}:${local.uat_jenkins_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "uat-jenkins-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.uat_jenkins_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "uat-jenkins-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_uat_jenkins_role_arn" {
    value = aws_iam_role.uat_jenkins_role.arn
}