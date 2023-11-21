# aws_iam_policy.ups_uat_grafana_policy:
resource "aws_iam_policy" "ups_uat_grafana_policy" {
    description = "ups-uat-grafana-permissions"
    name        = "ups-uat-grafana-permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadingMetricsFromCloudWatch",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetInsightRuleReport"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingLogsFromCloudWatch",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingTagsInstancesRegionsFromEC2",
      "Effect": "Allow",
      "Action": ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingResourcesForTags",
      "Effect": "Allow",
      "Action": "tag:GetResources",
      "Resource": "*"
    }
  ]
}
EOT

  tags = merge(local.tags,tomap({"Name" = "ups-uat-grafana-policy"}))
}


locals {
    ups_uat_grafana_namespace = "prom"
    ups_uat_grafana_serviceaccount = "prometheus-grafana"
}

# aws_iam_role.ups_uat_grafana_role:
resource "aws_iam_role" "ups_uat_grafana_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_uat_grafana_namespace}:${local.ups_uat_grafana_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups-uat-grafana-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_uat_grafana_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-uat-grafana-role"
    path                  = "/"

    tags = merge(local.tags,tomap({"Name" = "ups-uat-grafana-role"}))

}

output "ups_uat_grafana_s3_role_arn" {
    value = aws_iam_role.ups_uat_grafana_role.arn
}