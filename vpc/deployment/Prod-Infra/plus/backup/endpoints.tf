resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.terraform_remote_state.prod_infra.outputs.vpc_prod_infra_1_id
  service_name = "com.amazonaws.ap-south-1.s3"
  route_table_ids = [data.terraform_remote_state.prod_infra.outputs.prod_app_k8s_private_rt]
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = data.terraform_remote_state.prod_infra.outputs.vpc_prod_infra_1_id
  service_name = "com.amazonaws.ap-south-1.dynamodb"
  route_table_ids = [data.terraform_remote_state.prod_infra.outputs.prod_app_k8s_private_rt]
}