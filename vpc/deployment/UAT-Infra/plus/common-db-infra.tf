locals {
    uat_infra_vpc2_name = "uat-infra-db1"
    uat_infra_vpc2_cidr = "10.0.33.0/26"
    uat_app_k8s_private1_cidr = aws_subnet.uat_app_k8s_private1.cidr_block
    uat_app_k8s_private2_cidr = aws_subnet.uat_app_k8s_private2.cidr_block
}


#Define the db infra for cde category 1 and category2
resource "aws_vpc" "uat_infra_db1" {
  ipv4_ipam_pool_id = "ipam-pool-0b199f5a6a437ea04"
  cidr_block       = local.uat_infra_vpc2_cidr
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = merge(local.tags,tomap({"Name" = "uat-infra-db1"}))
}

output "vpc_uat_db1_id" {
  value = aws_vpc.uat_infra_db1.id
}

resource "aws_vpc_peering_connection" "uat_infra1_db1_pc" {
  peer_owner_id = var.account_id
  peer_vpc_id   = aws_vpc.uat_infra_1.id
  vpc_id        = aws_vpc.uat_infra_db1.id
  auto_accept   = true

  tags = merge(local.tags,tomap({"Name" = "VPC Peering between uat infra1 vpc and db1 vpc"}))
}

output "uat_infra1_db1_pc_id" {
  value = aws_vpc_peering_connection.uat_infra1_db1_pc.id
}


resource "aws_subnet" "uat_db1_private1" {
  vpc_id     = aws_vpc.uat_infra_db1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.33.0/28"

  tags = merge(local.tags,tomap({"Name" = "uat-db1-private1"}))
}

output "uat_db1_private1_id" {
  value = aws_subnet.uat_db1_private1.id
}

output "uat_db1_private2_id" {
  value = aws_subnet.uat_db1_private2.id
}

output "uat_db1_private1_cidr" {
  value = aws_subnet.uat_db1_private1.cidr_block
}

output "uat_db1_private2_cidr" {
  value = aws_subnet.uat_db1_private2.cidr_block
}


resource "aws_subnet" "uat_db1_private2" {
  vpc_id     = aws_vpc.uat_infra_db1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.33.16/28"

  tags = merge(local.tags,tomap({"Name" = "uat-db1-private2"}))
}

resource "aws_route_table" "uat_db1_private_rt" {
  vpc_id     = aws_vpc.uat_infra_db1.id

  route {
    cidr_block = aws_subnet.uat_app_k8s_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_infra1_db1_pc.id
  }

   route {
    cidr_block = aws_subnet.uat_app_k8s_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_infra1_db1_pc.id
  }

  tags = merge(local.tags,tomap({"Name" = "uat-db1-private-rt"}))
}

resource "aws_route_table_association" "uat_db1_private_rt_association1" {
  subnet_id      = aws_subnet.uat_db1_private1.id
  route_table_id = aws_route_table.uat_db1_private_rt.id
}

resource "aws_route_table_association" "uat_db1_private_rt_association2" {
  subnet_id      = aws_subnet.uat_db1_private2.id
  route_table_id = aws_route_table.uat_db1_private_rt.id
}



resource "aws_ram_resource_share" "share_uat_db1_to_uat_application" {
  name                      = local.uat_infra_vpc2_name
  allow_external_principals = false

  tags = {
    Environment = "uat"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_uat_db1_to_uat_application_association" {
  principal          = local.uat_application_account_id
  resource_share_arn = aws_ram_resource_share.share_uat_db1_to_uat_application.arn
}

locals {
  uat_db1_private_subnets_arns = [aws_subnet.uat_db1_private1.arn, aws_subnet.uat_db1_private2.arn]
}

resource "aws_ram_resource_association" "share_private_subnets_db1_vpc_to_uat_application" {
  count = length(local.uat_db1_private_subnets_arns)
  resource_arn       = local.uat_db1_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_uat_db1_to_uat_application.arn
}

