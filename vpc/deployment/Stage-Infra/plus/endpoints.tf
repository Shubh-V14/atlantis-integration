resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.stage_infra_1.id
  service_name = "com.amazonaws.ap-south-1.s3"
  route_table_ids = [aws_route_table.stage_app_k8s_private_rt.id]
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.stage_infra_1.id
  service_name = "com.amazonaws.ap-south-1.dynamodb"
  route_table_ids = [aws_route_table.stage_app_k8s_private_rt.id]
}