
resource "aws_subnet" "prod_k8s_cluster_private1" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.128.0/26"

  tags = {
    Name = "prod-k8s-cluster-private1"
    Environment = "prod"
    Terraform = "true"
  }
}

output "prod_k8s_cluster_private1_cidr" {
  value = aws_subnet.prod_k8s_cluster_private1.cidr_block
}

output "prod_k8s_cluster_private2_cidr" {
  value = aws_subnet.prod_k8s_cluster_private2.cidr_block
}

output "prod_k8s_cluster_private1_id" {
  value = aws_subnet.prod_k8s_cluster_private1.id
}

output "prod_k8s_cluster_private2_id" {
  value = aws_subnet.prod_k8s_cluster_private2.id
}

resource "aws_subnet" "prod_k8s_cluster_private2" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.128.64/26"

  tags = {
    Name = "prod-k8s-cluster-private2"
    Environment = "prod"
    Terraform = "true"
  }
}

locals {
  prod_k8s_cluster_private_subnets = [aws_subnet.prod_k8s_cluster_private1, aws_subnet.prod_k8s_cluster_private2]
}

resource "aws_ram_resource_association" "share_private_subnets_to_prod_application" {
  count = length(local.prod_k8s_cluster_private_subnets)
  resource_arn       = local.prod_k8s_cluster_private_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_infra_to_prod_application.arn
}






##############################

resource "aws_route_table" "prod_k8s_cluster_private_rt" {
  count = length(local.prod_k8s_cluster_private_subnets)
  vpc_id     = aws_vpc.prod_noncde_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = local.firewall_egress_nats[count.index].id
  }

  route {
    cidr_block = aws_subnet.clientvpn_private1.cidr_block
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  route {
    cidr_block = aws_subnet.clientvpn_private2.cidr_block
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-private-rt-${count.index + 1}"}))
}

output "uat_app_k8s_private_rt" {
  value = aws_route_table.prod_k8s_cluster_private_rt[*].id
}


resource "aws_route_table_association" "uat_app_k8s_private_rt_association" {
  count = length(local.prod_k8s_cluster_private_subnets)
  subnet_id      = local.prod_k8s_cluster_private_subnets[count.index].id
  route_table_id = aws_route_table.prod_k8s_cluster_private_rt[count.index].id
}