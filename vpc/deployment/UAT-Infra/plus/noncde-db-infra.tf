
locals {
    uat_noncde_db_infra1_vpc_name = "uat-noncde-db-infra-1"
    uat_noncde_db_infra1_vpc_cidr_block = "10.0.33.64/26"
}


resource "aws_vpc" "uat_noncde_db_infra1" {
  ipv4_ipam_pool_id = "ipam-pool-0b199f5a6a437ea04"
  cidr_block       = local.uat_noncde_db_infra1_vpc_cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-db-infra1"}))
}

output "vpc_uat_noncde_db_infra_id" {
  value = aws_vpc.uat_noncde_db_infra1.id
}

resource "aws_vpc_peering_connection" "uat_noncde_db_infra1_pc" {
  peer_owner_id = var.account_id
  peer_vpc_id   = aws_vpc.uat_infra_1.id
  vpc_id        = aws_vpc.uat_noncde_db_infra1.id
  auto_accept   = true

  tags = merge(local.tags,tomap({"Name" = "VPC Peering between uat noncde db infra1 vpc and uat infra1 vpc"}))
}

output "uat_noncde_db_infra1_uat_infra1_pcid" {
  value = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
}

resource "aws_subnet" "uat_noncde_db1_private1" {
  vpc_id     = aws_vpc.uat_noncde_db_infra1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.33.64/28"

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-db1-private1"}))
}

output "uat_noncde_db1_private1_id" {
  value = aws_subnet.uat_noncde_db1_private1.id
}

output "uat_noncde_db1_private2_id" {
  value = aws_subnet.uat_noncde_db1_private2.id
}

output "uat_noncde_db1_private1_cidr" {
  value = aws_subnet.uat_noncde_db1_private1.cidr_block
}

output "uat_noncde_db1_private2_cidr" {
  value = aws_subnet.uat_noncde_db1_private2.cidr_block
}

output "uat_noncde_db1_private1_subnet" {
  value = aws_subnet.uat_noncde_db1_private1
}

output "uat_noncde_db1_private2_subnet" {
  value = aws_subnet.uat_noncde_db1_private2
}


resource "aws_subnet" "uat_noncde_db1_private2" {
  vpc_id     = aws_vpc.uat_noncde_db_infra1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.33.80/28"

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-db1-private2"}))
}

resource "aws_route_table" "uat_noncde_db1_private_rt" {
  vpc_id     = aws_vpc.uat_noncde_db_infra1.id

  route {
    cidr_block = aws_subnet.uat_noncde_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }

   route {
    cidr_block = aws_subnet.uat_noncde_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }

   route {
    cidr_block = aws_subnet.uat_app_k8s_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }

   route {
    cidr_block = aws_subnet.uat_app_k8s_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }


  tags = merge(local.tags,tomap({"Name" = "uat-noncde-db1-private-rt"}))
}

resource "aws_route_table_association" "uat_noncde_db1_private_rt_association1" {
  subnet_id      = aws_subnet.uat_noncde_db1_private1.id
  route_table_id = aws_route_table.uat_noncde_db1_private_rt.id
}

resource "aws_route_table_association" "uat_noncde_db1_private_rt_association2" {
  subnet_id      = aws_subnet.uat_noncde_db1_private2.id
  route_table_id = aws_route_table.uat_noncde_db1_private_rt.id
}



resource "aws_ram_resource_share" "share_uat_noncde_db1_to_uat_application" {
  name                      = local.uat_noncde_db_infra1_vpc_name
  allow_external_principals = false

  tags = {
    Environment = "uat"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_uat_noncde_db1_to_uat_application_association" {
  principal          = local.uat_application_account_id
  resource_share_arn = aws_ram_resource_share.share_uat_noncde_db1_to_uat_application.arn
}

locals {
  uat_noncde_db1_private_subnets_arns = [aws_subnet.uat_noncde_db1_private1.arn, aws_subnet.uat_noncde_db1_private2.arn]
}

resource "aws_ram_resource_association" "share_private_subnets_noncde_db1_vpc_to_uat_application" {
  count = length(local.uat_noncde_db1_private_subnets_arns)
  resource_arn       = local.uat_noncde_db1_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_uat_noncde_db1_to_uat_application.arn
}

