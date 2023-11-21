locals {
    services_for_dynamodb_permissions = ["pam-service", "payments-service"]
    namespace = "in1"
}

# aws_iam_policy.ups_uat_customer_service_policy:
resource "aws_iam_policy" "ups_uat_dynamodb_policy" {
    count = length(local.services_for_dynamodb_permissions)
    description = "ups-uat-${local.services_for_dynamodb_permissions[count.index]}-permissions"
    name = "ups-uat-${local.services_for_dynamodb_permissions[count.index]}-permissions"
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
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/NONCDE_${local.services_for_dynamodb_permissions[count.index]}_tenant_references",
                "arn:aws:dynamodb:ap-south-1:${var.account_id}:table/NONCDE_${local.services_for_dynamodb_permissions[count.index]}_tenant_references/*"
            ]
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


locals {
    service_env_set_for_dynamodb_permissions = [for s in local.service_env_set: s if contains(local.services_for_dynamodb_permissions, s[1])]
}

data "aws_iam_role" "service_role" {
  count = length(local.service_env_set_for_dynamodb_permissions)
  name = "${local.service_env_set_for_dynamodb_permissions[count.index][0][1]}-${local.service_env_set_for_dynamodb_permissions[count.index][0][0]}-${local.service_env_set_for_dynamodb_permissions[count.index][1]}-role"
  depends_on = [ aws_iam_role.service_role ]
}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_permissions_to_service_role" {
  count = length(local.service_env_set_for_dynamodb_permissions)
  role       = data.aws_iam_role.service_role[count.index].name
  policy_arn = aws_iam_policy.ups_uat_dynamodb_policy[count.index].arn
}
