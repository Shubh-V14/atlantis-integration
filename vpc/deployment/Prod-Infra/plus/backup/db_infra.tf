locals {
    prod_infra_vpc2_name = "prod-infra-db1"
    prod_infra_vpc2_cidr = "10.0.160.0/26"
    prod_app_k8s_private1_cidr = data.terraform_remote_state.prod_infra.outputs.prod_app_k8s_private1_cidr
    prod_app_k8s_private2_cidr = data.terraform_remote_state.prod_infra.outputs.prod_app_k8s_private2_cidr
}


resource "aws_vpc" "prod_infra_db1" {
  ipv4_ipam_pool_id = "ipam-pool-032220a8f1e82c627"
  cidr_block       = local.prod_infra_vpc2_cidr
  instance_tenancy = "default"

  tags = {
    Name = "prod-infra-db1"
    Environment = "prod"
    Terraform = "true"
  }
}

output "vpc_prod_db1_id" {
  value = aws_vpc.prod_infra_db1.id
}

resource "aws_vpc_peering_connection" "prod_infra1_db1_pc" {
  peer_owner_id = var.account_id
  peer_vpc_id   = data.terraform_remote_state.prod_infra.outputs.vpc_prod_infra_1_id
  vpc_id        = aws_vpc.prod_infra_db1.id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between prod infra1 vpc and db1 vpc"
  }
}

output "prod_infra1_db1_pc_id" {
  value = aws_vpc_peering_connection.prod_infra1_db1_pc.id
}


resource "aws_subnet" "prod_db1_private1" {
  vpc_id     = aws_vpc.prod_infra_db1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.160.0/28"

  tags = {
    Name = "prod-db1-private1"
    Environment = "prod"
    Terraform = "true"
  }
}

output "prod_db1_private1_id" {
  value = aws_subnet.prod_db1_private1.id
}

output "prod_db1_private2_id" {
  value = aws_subnet.prod_db1_private2.id
}

output "prod_db1_private1_cidr" {
  value = aws_subnet.prod_db1_private1.cidr_block
}

output "prod_db1_private2_cidr" {
  value = aws_subnet.prod_db1_private2.cidr_block
}


resource "aws_subnet" "prod_db1_private2" {
  vpc_id     = aws_vpc.prod_infra_db1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.160.16/28"

  tags = {
    Name = "prod-db1-private2"
    Environment = "prod"
    Terraform = "true"
  }
}

resource "aws_route_table" "prod_db1_private_rt" {
  vpc_id     = aws_vpc.prod_infra_db1.id

  route {
    cidr_block = local.prod_infra_app_k8s_private1_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_infra1_db1_pc.id
  }

   route {
    cidr_block = local.prod_infra_app_k8s_private2_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_infra1_db1_pc.id
  }


  tags = {
    Name = "prod-db1-private-rt"
    Environment = "prod"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "prod_db1_private_rt_association1" {
  subnet_id      = aws_subnet.prod_db1_private1.id
  route_table_id = aws_route_table.prod_db1_private_rt.id
}

resource "aws_route_table_association" "prod_db1_private_rt_association2" {
  subnet_id      = aws_subnet.prod_db1_private2.id
  route_table_id = aws_route_table.prod_db1_private_rt.id
}



resource "aws_ram_resource_share" "share_prod_db1_to_prod_application" {
  name                      = local.prod_infra_vpc2_name
  allow_external_principals = false

  tags = {
    Environment = "prod"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_prod_db1_to_prod_application_association" {
  principal          = local.prod_application_account_id
  resource_share_arn = aws_ram_resource_share.share_prod_db1_to_prod_application.arn
}

locals {
  prod_db1_private_subnets_arns = [aws_subnet.prod_db1_private1.arn, aws_subnet.prod_db1_private2.arn]
}

resource "aws_ram_resource_association" "share_private_subnets_db1_vpc_to_prod_application" {
  count = length(local.prod_db1_private_subnets_arns)
  resource_arn       = local.prod_db1_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_prod_db1_to_prod_application.arn
}

