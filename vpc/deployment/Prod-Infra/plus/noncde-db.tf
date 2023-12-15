
locals {
    prod_noncde_db_vpc_cidr_block = "10.0.192.128/26"
}


resource "aws_vpc" "prod_noncde_db" {
  ipv4_ipam_pool_id = "ipam-pool-028cadfba5189b4e6"
  cidr_block       = local.prod_noncde_db_vpc_cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-db"}))
}

output "vpc_prod_noncde_db_infra_id" {
  value = aws_vpc.prod_noncde_db.id
}

resource "aws_vpc_peering_connection" "prod_noncde_db_pc" {
  peer_owner_id = var.account_id
  peer_vpc_id   = aws_vpc.prod_noncde_infra_1.id
  vpc_id        = aws_vpc.prod_noncde_db.id
  auto_accept   = true

  tags = merge(local.tags,tomap({"Name" = "VPC Peering between prod noncde backend db vpc and prod noncde infra1 vpc"}))

}

output "prod_noncde_db_prod_noncde_infra1_pcid" {
  value = aws_vpc_peering_connection.prod_noncde_db_pc.id
}

resource "aws_subnet" "prod_noncde_db_private1" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_db.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.192.128/27"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-db-private1"}))
}

output "prod_noncde_db_private1_id" {
  value = aws_subnet.prod_noncde_db_private1.id
}

output "prod_noncde_db_private2_id" {
  value = aws_subnet.prod_noncde_db_private2.id
}

output "prod_noncde_db_private1_cidr" {
  value = aws_subnet.prod_noncde_db_private1.cidr_block
}

output "prod_noncde_db_private2_cidr" {
  value = aws_subnet.prod_noncde_db_private2.cidr_block
}

output "prod_noncde_db_private1_subnet" {
  value = aws_subnet.prod_noncde_db_private1
}

output "prod_noncde_db_private2_subnet" {
  value = aws_subnet.prod_noncde_db_private2
}


resource "aws_subnet" "prod_noncde_db_private2" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_db.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.192.160/27"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-db-private2"}))
}

resource "aws_route_table" "prod_noncde_db_private_rt" {
  vpc_id     = aws_vpc.prod_noncde_db.id

  route {
    cidr_block = aws_subnet.prod_noncde_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

   route {
    cidr_block = aws_subnet.prod_noncde_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

   route {
    cidr_block = aws_subnet.prod_noncde_private3.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }
  route {
    cidr_block = aws_subnet.prod_noncde_private4.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

   route {
    cidr_block = aws_subnet.prod_noncde_private5.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

  route {
    cidr_block = aws_subnet.prod_noncde_private6.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

   route {
    cidr_block = aws_subnet.prod_k8s_cluster_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

   route {
    cidr_block = aws_subnet.prod_k8s_cluster_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }


  tags = merge(local.tags,tomap({"Name" = "prod-noncde-db-private-rt"}))
}

resource "aws_route_table_association" "prod_noncde_db_private_rt_association1" {
  subnet_id      = aws_subnet.prod_noncde_db_private1.id
  route_table_id = aws_route_table.prod_noncde_db_private_rt.id
}

resource "aws_route_table_association" "prod_noncde_db_private_rt_association2" {
  subnet_id      = aws_subnet.prod_noncde_db_private2.id
  route_table_id = aws_route_table.prod_noncde_db_private_rt.id
}



resource "aws_ram_resource_share" "share_prod_noncde_db_to_prod_application" {
  name                      = "share-prod-noncde-db-prod-application"
  allow_external_principals = false

  tags = {
    Environment = "uat"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_prod_noncde_db_to_prod_application_association" {
  principal          = local.prod_application_account_id
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_db_to_prod_application.arn
}

locals {
  prod_noncde_db_private_subnets_arns = [aws_subnet.prod_noncde_db_private1.arn, aws_subnet.prod_noncde_db_private2.arn]
}

resource "aws_ram_resource_association" "share_private_subnets_noncde_db_vpc_to_prod_application" {
  count = length(local.prod_noncde_db_private_subnets_arns)
  resource_arn       = local.prod_noncde_db_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_db_to_prod_application.arn
}

