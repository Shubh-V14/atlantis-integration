# aws_iam_policy.ups_stage_frame_policy:
resource "aws_iam_policy" "ups_stage_frame_policy" {
    description = "ups-stage-frame-permissions"
    name        = "ups-stage-frame-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCreateTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateTable"
            ],
            "Resource": [
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/*"
            ]
        },
        {
            "Sid": "AllowAllOperations",
            "Effect": "Allow",
            "Action": [
                "dynamodb:*"
            ],
            "Resource": [
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/RuleInfo_*"
            ]
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}

locals {
    services_for_frame_permissions = ["frame-service"]
    service_env_set_for_frame_permissions = [for s in local.service_env_set: s if contains(local.services_for_frame_permissions, s[1])]
}

data "aws_iam_role" "frame_service_role" {
  count = length(local.service_env_set_for_frame_permissions)
  name = "${local.service_env_set_for_frame_permissions[count.index][0][1]}-${local.service_env_set_for_frame_permissions[count.index][0][0]}-${local.service_env_set_for_frame_permissions[count.index][1]}-role"
  depends_on = [ aws_iam_role.service_role ]
}

resource "aws_iam_role_policy_attachment" "attach_frame_permissions_to_service_role" {
  count = length(local.service_env_set_for_frame_permissions)
  role       = data.aws_iam_role.frame_service_role[count.index].name
  policy_arn = aws_iam_policy.ups_stage_frame_policy.arn
}
