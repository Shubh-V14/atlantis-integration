# aws_iam_policy.ups_uat_loki_policy:
resource "aws_iam_policy" "flow_log_permissions" {
    description = "ups-flow-log-permissions"
    name        = "ups-flow-log-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


# aws_iam_role.ups_uat_loki_role:
resource "aws_iam_role" "ups_flow_logs_creator" {
    assume_role_policy    = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
} 
EOT
    description           = "ups-flow-logs-creator"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.flow_log_permissions.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-flow-log-creator"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_flow_log_creator_role_arn" {
    value = aws_iam_role.ups_flow_logs_creator.arn
}

resource "aws_cloudwatch_log_group" "shared_infra_3_flow_logs" {
  name = "share-infra-3-flow-logs"
  retention_in_days = 30
}

resource "aws_flow_log" "shared_infra_3_flow_logs" {
  iam_role_arn    = aws_iam_role.ups_flow_logs_creator.arn
  log_destination = aws_cloudwatch_log_group.shared_infra_3_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id = aws_vpc.shared_infra_3.id
}