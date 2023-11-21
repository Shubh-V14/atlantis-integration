resource "aws_subnet" "uat_app_k8s_private1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.48.0/22"

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-private1", "kubernetes.io/role/internal-elb" = "1" }))
}

output "uat_app_k8s_private1_subnet" {
  value = aws_subnet.uat_app_k8s_private1
}

output "uat_app_k8s_private2_subnet" {
  value = aws_subnet.uat_app_k8s_private2
}


output "uat_app_k8s_private1_cidr" {
  value = aws_subnet.uat_app_k8s_private1.cidr_block
}

output "uat_app_k8s_private2_cidr" {
  value = aws_subnet.uat_app_k8s_private2.cidr_block
}

resource "aws_subnet" "uat_app_k8s_private2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block =  "10.0.52.0/22"

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-private2", "kubernetes.io/role/internal-elb" = "1" }))

}

resource "aws_subnet" "uat_app_k8s_public1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.56.0/27"

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-public1", "kubernetes.io/role/elb" = "1" }))
}

resource "aws_subnet" "uat_app_k8s_public2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.56.32/27"

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-public2", "kubernetes.io/role/elb" = "1" }))
}


output "uat_app_k8s_public1_subnet" {
  value = aws_subnet.uat_app_k8s_public1
}

output "uat_app_k8s_public2_subnet" {
  value = aws_subnet.uat_app_k8s_public2
}

resource "aws_internet_gateway" "uat_app_k8s_igw" {
  vpc_id     = aws_vpc.uat_infra_1.id

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-igw"}))

}
resource "aws_eip" "uat_app_k8s_ngw_eip" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-ngw-eip"}))
}



resource "aws_nat_gateway" "uat_app_k8s_ngw" {
  allocation_id = aws_eip.uat_app_k8s_ngw_eip.id
  subnet_id     = aws_subnet.uat_app_k8s_public1.id

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-gw-NAT"}))


  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.uat_app_k8s_igw]
}

locals {
  uat_db1_private1_cidr = aws_subnet.uat_db1_private1.cidr_block
  uat_db1_private2_cidr = aws_subnet.uat_db1_private2.cidr_block
  uat_infra1_db1_pc_id = aws_vpc_peering_connection.uat_infra1_db1_pc.id
  utkarsh_cidrs = [
    "10.172.223.113/32",
    "10.172.223.15/32",
    "172.16.213.27/32",
    "10.184.14.40/32"
  ]
  hitachi_ips = {"visa": {"ips": ["172.18.24.40/32", "172.18.24.41/32"]}, "rupay":{"ips":["192.168.62.223/32"]}}
  firewall_endpoints = [local.vpce_ap-south-1a, local.vpce_ap-south-1c]
}


resource "aws_route_table" "uat_app_k8s_public_rt" {
  count = length(local.firewall_endpoints)
  vpc_id     = aws_vpc.uat_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  route {
    cidr_block = local.shared_infra_clientvpn_private1_sub_cidr
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  route {
    cidr_block = local.shared_infra_clientvpn_private2_sub_cidr
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }


  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-public-rt-${count.index}"}))
}

resource "aws_route_table_association" "uat_app_k8s_public_rt_association1" {
  subnet_id      = aws_subnet.uat_app_k8s_public1.id
  route_table_id = aws_route_table.uat_app_k8s_public_rt[0].id
}

resource "aws_route_table_association" "uat_app_k8s_public_rt_association2" {
  subnet_id      = aws_subnet.uat_app_k8s_public2.id
  route_table_id = aws_route_table.uat_app_k8s_public_rt[1].id
}

locals {
  firewall_egress_nats = [aws_nat_gateway.uat_firewall1_ngw1.id, aws_nat_gateway.uat_firewall1_ngw2.id]
}

resource "aws_route_table" "uat_app_k8s_private_rt" {
  count = length(local.firewall_egress_nats)
  vpc_id     = aws_vpc.uat_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = local.firewall_egress_nats[count.index]
  }

  route {
    cidr_block = local.shared_infra_clientvpn_private1_sub_cidr
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  route {
    cidr_block = local.shared_infra_clientvpn_private2_sub_cidr
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }


  #connect to db subnet over peering

 route {
    cidr_block = local.uat_db1_private1_cidr
    vpc_peering_connection_id = local.uat_infra1_db1_pc_id
  }


 route {
    cidr_block = local.uat_db1_private2_cidr
    vpc_peering_connection_id = local.uat_infra1_db1_pc_id
  }

  #COnnect to cde db

   route {
    cidr_block = aws_subnet.uat_cde_db1_private1.cidr_block
    vpc_peering_connection_id = local.uat_infra1_db1_pc_id
  }


 route {
    cidr_block = aws_subnet.uat_cde_db1_private2.cidr_block
    vpc_peering_connection_id = local.uat_infra1_db1_pc_id
  }

# Connect to non cde db
 route {
    cidr_block = aws_subnet.uat_noncde_db1_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }


 route {
    cidr_block = aws_subnet.uat_noncde_db1_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }



  # route {
  #   cidr_block = data.terraform_remote_state.shared_infra.outputs.ad_private2_cidr
  #   vpc_endpoint_id = local.firewall_endpoints[count.index]
  # }

  #  route {
  #   cidr_block = data.terraform_remote_state.shared_infra.outputs.ad_private1_cidr
  #   vpc_endpoint_id = local.firewall_endpoints[count.index]
  # }

  # route {
  #   cidr_block = data.terraform_remote_state.shared_infra.outputs.ad_public1_cidr
  #   vpc_endpoint_id = local.firewall_endpoints[count.index]
  # }

  tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-private-rt-${count.index + 1}"}))
}

# output "uat_app_k8s_private_rt" {
#   value = aws_route_table.uat_app_k8s_private_rt.id
# }

locals {
  k8s_private_subnets = [aws_subnet.uat_app_k8s_private1, aws_subnet.uat_app_k8s_private2 ]
  k8s_private_subnets_cidr = [aws_subnet.uat_app_k8s_private1.cidr_block, aws_subnet.uat_app_k8s_private2.cidr_block ]
  cde_k8s_private_subnets = [aws_subnet.uat_cde_private1, aws_subnet.uat_cde_private2 ]
  noncde_k8s_private_subnets = [aws_subnet.uat_noncde_private1, aws_subnet.uat_noncde_private2]
  k8s_public_subnets = [aws_subnet.uat_app_k8s_public1, aws_subnet.uat_app_k8s_public2 ]
  k8s_public_subnets_cidr = [aws_subnet.uat_app_k8s_public1.cidr_block, aws_subnet.uat_app_k8s_public2.cidr_block ]
  cde_k8s_public_subnets = [aws_subnet.uat_cde_public1, aws_subnet.uat_cde_public2 ]
  cde_k8s_public_subnets_cidr = [aws_subnet.uat_cde_public1.cidr_block, aws_subnet.uat_cde_public2.cidr_block ]
  noncde_k8s_public_subnets = [aws_subnet.uat_noncde_public1, aws_subnet.uat_noncde_public2 ]
  noncde_k8s_public_subnets_cidr = [aws_subnet.uat_noncde_public1.cidr_block, aws_subnet.uat_noncde_public2.cidr_block ]
}

resource "aws_route_table_association" "uat_app_k8s_private_rt_association" {
  count = length(local.k8s_private_subnets)
  subnet_id      = local.k8s_private_subnets[count.index].id
  route_table_id = aws_route_table.uat_app_k8s_private_rt[count.index].id
}


variable account_mapping {
  type = map(string)
}

locals {
  uat_application_account_id = lookup(var.account_mapping, "UAT-Application", 0)
}

resource "aws_ram_principal_association" "share_infra_to_uat_application" {
  principal          = local.uat_application_account_id
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

locals {
  uat_k8s_public_subnets_arns = [aws_subnet.uat_app_k8s_public1.arn, aws_subnet.uat_app_k8s_public2.arn]
  uat_k8s_private_subnets_arns = [aws_subnet.uat_app_k8s_private1.arn, aws_subnet.uat_app_k8s_private2.arn]
  internal_tgw_id = "tgw-0ba44a757bc9843f6"
  internal_tgw_rt_id = "tgw-rtb-0ac1f73214e984bea"
}

resource "aws_ram_resource_association" "share_private_subnets_to_uat_application" {
  count = length(local.uat_k8s_private_subnets_arns)
  resource_arn       = local.uat_k8s_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

resource "aws_ram_resource_association" "share_public_subnets_to_uat_application" {
  count = length(local.uat_k8s_public_subnets_arns)
  resource_arn       = local.uat_k8s_public_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

resource "aws_route_table" "igw_ingress_rt" {
vpc_id = aws_vpc.uat_infra_1.id

dynamic "route" {
    for_each = local.k8s_public_subnets
    content {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

dynamic "route" {
    for_each = local.cde_k8s_public_subnets
    content {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

dynamic "route" {
    for_each = local.noncde_k8s_public_subnets
    content {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

dynamic "route" {
    for_each = local.firewall_egress_subnets
    content {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

  tags = merge(local.tags,tomap({"Name" = "uat-infra1-igw-ingress-rt"}))
}

resource "aws_network_acl" "uat_common_private_nacl" {
  vpc_id = aws_vpc.uat_infra_1.id

  egress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_subnet.uat_app_k8s_public1.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 54
    action     = "deny"
    cidr_block = aws_subnet.uat_app_k8s_public1.cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 58
    action     = "allow"
    cidr_block = aws_subnet.uat_app_k8s_public2.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 59
    action     = "deny"
    cidr_block = aws_subnet.uat_app_k8s_public2.cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # dynamic "ingress" {
  #   for_each = [80, 443, 3128]
  #   content {
  #     protocol   = "tcp"
  #     rule_no    = 61 + "${ingress.key}"
  #     action     = "allow"
  #     cidr_block = aws_subnet.uat_app_k8s_public1.cidr_block
  #     from_port  = "${ingress.value}"
  #     to_port    = "${ingress.value}"
  #   }
  # }

  # ingress {
  #   protocol   = -1
  #   rule_no    = 65
  #   action     = "deny"
  #   cidr_block = aws_subnet.uat_app_k8s_public1.cidr_block
  #   from_port  = 0
  #   to_port    = 0
  # }

  # dynamic "ingress" {
  #   for_each = [80, 443, 15021]
  #   content {
  #     protocol   = "tcp"
  #     rule_no    = 66 + "${ingress.key}"
  #     action     = "allow"
  #     cidr_block = aws_subnet.uat_app_k8s_public2.cidr_block
  #     from_port  = "${ingress.value}"
  #     to_port    = "${ingress.value}"
  #   }
  # }

  # ingress {
  #   protocol   = -1
  #   rule_no    = 70
  #   action     = "deny"
  #   cidr_block = aws_subnet.uat_app_k8s_public2.cidr_block
  #   from_port  = 0
  #   to_port    = 0
  # }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "uat-common-private-nacl"
  }
}
locals {
  uat_app_k8s_private_subnets = [aws_subnet.uat_app_k8s_private1, aws_subnet.uat_app_k8s_private2]
}

resource "aws_network_acl_association" "common_private" {
  count = length(local.uat_app_k8s_private_subnets)
  network_acl_id = aws_network_acl.uat_common_private_nacl.id
  subnet_id      = local.uat_app_k8s_private_subnets[count.index].id
}




###########
#PUBLIC NACL
###########


resource "aws_network_acl" "uat_app_k8s_public_nacl" {
  vpc_id = aws_vpc.uat_infra_1.id




  ingress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_vpc.uat_infra_1.cidr_block
    from_port  = 0
    to_port    = 65535
  }


  dynamic "ingress" {
    for_each = [80, 443, 3128]
    content {
      protocol   = "tcp"
      rule_no    = 60 + "${ingress.key}"
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  egress {
    protocol   = "tcp"
    rule_no    = 70
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  tags = {
    Name = "uat-app-k8s-public-nacl"
  }
}

locals {
  uat_app_k8s_public_subnets = [aws_subnet.uat_app_k8s_public1, aws_subnet.uat_app_k8s_public2]
}

resource "aws_network_acl_association" "app_k8s_public" {
  count = length(local.uat_app_k8s_public_subnets)
  network_acl_id = aws_network_acl.uat_app_k8s_public_nacl.id
  subnet_id      = local.uat_app_k8s_public_subnets[count.index].id
}