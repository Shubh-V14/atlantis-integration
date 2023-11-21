#Used for temporary storage via customer service
module "service_dump_prod_s3" {
  source = "../../../modules/s3_v2"
  bucket_name = "service-dump-prod"
  expiry_days =  7
}


locals {
    service_env_set_with_all_props_for_service_dump_permissions = [for s in local.service_env_set_with_all_props: s if try(s[1].type, "") != "node"]
}
data "aws_iam_role" "service_dump_service_role" {
  count = length(local.service_env_set_with_all_props_for_service_dump_permissions)
  name = "${local.service_env_set_with_all_props_for_service_dump_permissions[count.index][0][1]}-${local.service_env_set_with_all_props_for_service_dump_permissions[count.index][0][0]}-${local.service_env_set_with_all_props_for_service_dump_permissions[count.index][1].name}-role"
  depends_on = [ aws_iam_role.service_role ]
}

resource "aws_iam_role_policy_attachment" "attach_service_dump_permissions_to_service_role" {
  count = length(local.service_env_set_with_all_props_for_service_dump_permissions)
  role       = data.aws_iam_role.service_dump_service_role[count.index].name
  policy_arn = module.service_dump_prod_s3.iam_policy_arn
}
