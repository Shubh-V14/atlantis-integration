module "customer_support_attachments_s3_bucket" {
  source = "../../../modules/s3_v3"
  bucket_name = "upswing-${local.variant}-customer-support-attachments"
  expiry = {"enabled": false}
}

locals {
    services_for_customer_support_permissions = ["customer-support-service"]
    service_env_set_for_customer_support_permissions = [for s in local.service_env_set: s if contains(local.services_for_customer_support_permissions, s[1])]
}

data "aws_iam_role" "customer_support_service_role" {
  count = length(local.service_env_set_for_customer_support_permissions)
  name = "${local.service_env_set_for_customer_support_permissions[count.index][0][1]}-${local.service_env_set_for_customer_support_permissions[count.index][0][0]}-${local.service_env_set_for_customer_support_permissions[count.index][1]}-role"
  depends_on = [ aws_iam_role.service_role ]
}

resource "aws_iam_role_policy_attachment" "attach_customer_support_permissions_to_service_role" {
  count = length(local.service_env_set_for_customer_support_permissions)
  role       = data.aws_iam_role.customer_support_service_role[count.index].name
  policy_arn = module.customer_support_attachments_s3_bucket.iam_policy_arn
}

resource "aws_iam_role_policy_attachment" "attach_tratev_permissions_to_customer_support_service_role" {
  count = length(local.service_env_set_for_customer_support_permissions)
  role       = data.aws_iam_role.customer_support_service_role[count.index].name
  policy_arn = module.s3_trat_ev.iam_policy_arn
}