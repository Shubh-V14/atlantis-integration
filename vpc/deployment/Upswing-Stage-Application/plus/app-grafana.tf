module "grafana_role" {
  source = "../../../modules/app_role/v1"
  name = "grafana"
  namespace = "prom"
  serviceaccount = "prometheus-grafana"
  oidc_provider_url = local.oidc_provider_url 
  oidc_provider_arn = local.oidc_provider_arn
  variant = local.variant
  tags = local.tags
  account_id = var.account_id

  iam_policy = <<EOT
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
}

output "grafana_role" {
  value = module.grafana_role.role_arn
}

module "grafana_secrets" {
  source = "../../../modules/app_secret/v1"
  name = "grafana-secrets"
  namespace = "prom"
  secret_keys = ["client_id", "client_secret", "GF_DATABASE_PASSWORD"]
  secret_binary = module.grafana_secret.secret_binary
}