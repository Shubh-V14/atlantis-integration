locals {
    stage_infra_vpc2_name = "stage-infra-db1"
    stage_infra_vpc2_cidr = "10.0.80.0/25"
}


resource "aws_vpc" "stage_infra_db1" {
  ipv4_ipam_pool_id = "ipam-pool-002baa6c33f12bc6c"
  cidr_block       = local.stage_infra_vpc2_cidr
  instance_tenancy = "default"

  tags = {
    Name = "stage-infra-db1"
    Environment = "stage"
    Terraform = "true"
  }
}

output "vpc_stage_db1_id" {
  value = aws_vpc.stage_infra_db1.id
}

variable account_id {}

resource "aws_vpc_peering_connection" "stage_infra1_db1_pc" {
  peer_owner_id = var.account_id
  peer_vpc_id   = aws_vpc.stage_infra_1.id
  vpc_id        = aws_vpc.stage_infra_db1.id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between stage infra1 vpc and db1 vpc"
  }
}

output "stage_infra1_db1_pc_id" {
  value = aws_vpc_peering_connection.stage_infra1_db1_pc.id
}


resource "aws_subnet" "stage_db1_private1" {
  vpc_id     = aws_vpc.stage_infra_db1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.80.0/26"

  tags = {
    Name = "stage-db1-private1"
    Environment = "stage"
    Terraform = "true"
  }
}

output "stage_db1_private1_id" {
  value = aws_subnet.stage_db1_private1.id
}

output "stage_db1_private2_id" {
  value = aws_subnet.stage_db1_private2.id
}

output "stage_db1_private1_cidr" {
  value = aws_subnet.stage_db1_private1.cidr_block
}

output "stage_db1_private2_cidr" {
  value = aws_subnet.stage_db1_private2.cidr_block
}


resource "aws_subnet" "stage_db1_private2" {
  vpc_id     = aws_vpc.stage_infra_db1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.80.64/26"

  tags = {
    Name = "stage-db1-private2"
    Environment = "stage"
    Terraform = "true"
  }
}

resource "aws_route_table" "stage_db1_private_rt" {
  vpc_id     = aws_vpc.stage_infra_db1.id

  route {
    cidr_block = aws_subnet.stage_app_k8s_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.stage_infra1_db1_pc.id
  }

   route {
    cidr_block = aws_subnet.stage_app_k8s_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.stage_infra1_db1_pc.id
  }


  tags = {
    Name = "stage-db1-private-rt"
    Environment = "stage"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "stage_db1_private_rt_association1" {
  subnet_id      = aws_subnet.stage_db1_private1.id
  route_table_id = aws_route_table.stage_db1_private_rt.id
}

resource "aws_route_table_association" "stage_db1_private_rt_association2" {
  subnet_id      = aws_subnet.stage_db1_private2.id
  route_table_id = aws_route_table.stage_db1_private_rt.id
}



resource "aws_ram_resource_share" "share_stage_db1_to_stage_application" {
  name                      = local.stage_infra_vpc2_name
  allow_external_principals = false

  tags = {
    Environment = "stage"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_stage_db1_to_stage_application_association" {
  principal          = "537885521837" #Stage Application Account
  resource_share_arn = aws_ram_resource_share.share_stage_db1_to_stage_application.arn
}

locals {
  stage_db1_private_subnets_arns = [aws_subnet.stage_db1_private1.arn, aws_subnet.stage_db1_private2.arn]
}

resource "aws_ram_resource_association" "share_private_subnets_db1_vpc_to_stage_application" {
  count = length(local.stage_db1_private_subnets_arns)
  resource_arn       = local.stage_db1_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_stage_db1_to_stage_application.arn
}

