resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.prod_noncde_infra_1.id
  service_name = "com.amazonaws.ap-south-1.s3"
  route_table_ids = aws_route_table.prod_noncde_private_rt[*].id
  tags = merge(local.tags,tomap({"Name" = "prod-s3-endpoint"}))
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       =  aws_vpc.prod_noncde_infra_1.id
  service_name = "com.amazonaws.ap-south-1.dynamodb"
  route_table_ids = aws_route_table.prod_noncde_private_rt[*].id
  tags = merge(local.tags,tomap({"Name" = "prod-dynamodb-endpoint"}))
}
