resource "aws_subnet" "uat_firewall1_endpoint1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.56.128/28"

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-endpoint1"}))
}

resource "aws_subnet" "uat_firewall1_endpoint2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.56.144/28"

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-endpoint2"}))
}

resource "aws_subnet" "uat_firewall1_egress1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.56.160/28"

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-egress1"}))
}

resource "aws_subnet" "uat_firewall1_egress2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.56.176/28"

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-egress2"}))
}

output "uat_firewall1_endpoint1_cidr" {
  value = aws_subnet.uat_firewall1_endpoint1.cidr_block
}

output "uat_firewall1_endpoint2_cidr" {
  value = aws_subnet.uat_firewall1_endpoint2.cidr_block
}

resource "aws_subnet" "uat_firewall1_entrypoint1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.56.64/28"

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-entrypoint1"}))
}

resource "aws_subnet" "uat_firewall1_entrypoint2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.56.80/28"

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-entrypoint2"}))
}


resource "aws_eip" "uat_firewall_eip1" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-firewall-eip1"}))
}

resource "aws_eip" "uat_firewall_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-firewall-eip2"}))
}

resource "aws_nat_gateway" "uat_firewall1_ngw1" {
  allocation_id = aws_eip.uat_firewall_eip1.id
  subnet_id     = aws_subnet.uat_firewall1_egress1.id

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-NAT1"}))

  depends_on = [aws_internet_gateway.uat_app_k8s_igw]
}

resource "aws_nat_gateway" "uat_firewall1_ngw2" {
  allocation_id = aws_eip.uat_firewall_eip2.id
  subnet_id     = aws_subnet.uat_firewall1_egress2.id

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-NAT2"}))
  depends_on = [aws_internet_gateway.uat_app_k8s_igw]
}

locals {
    vpce_ap-south-1a = [for ss in aws_networkfirewall_firewall.uat_firewall1.firewall_status[0].sync_states : ss.attachment[0].endpoint_id if ss.availability_zone == "ap-south-1a"] [0]
    vpce_ap-south-1c = [for ss in aws_networkfirewall_firewall.uat_firewall1.firewall_status[0].sync_states : ss.attachment[0].endpoint_id if ss.availability_zone == "ap-south-1c"][0]
    firewall_endpoint_subnets = [aws_subnet.uat_firewall1_endpoint1.id, aws_subnet.uat_firewall1_endpoint2.id]
    firewall_egress_subnets = [aws_subnet.uat_firewall1_egress1, aws_subnet.uat_firewall1_egress2]
    firewall_entrypoint_subnets = [aws_subnet.uat_firewall1_entrypoint1.id, aws_subnet.uat_firewall1_entrypoint2.id]
}

resource "aws_route_table" "uat_firewall1_egress_rt" {
  count = length(local.firewall_endpoints)
  vpc_id     = aws_vpc.uat_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-egress-rt1"}))
}





resource "aws_route_table" "uat_firewall1_endpoint_rt" {
  depends_on = [ aws_ram_resource_share_accepter.accept_tgw_from_shared_infra ]
  vpc_id     = aws_vpc.uat_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.uat_app_k8s_igw.id
  }

  route {
    cidr_block = local.shared_infra_clientvpn_private1_sub_cidr
    transit_gateway_id = local.shared_infra_tgw_id
  }

  route {
    cidr_block = local.shared_infra_clientvpn_private2_sub_cidr
    transit_gateway_id = local.shared_infra_tgw_id
  }

  dynamic "route" {
    for_each = local.utkarsh_cidrs
    content {
      cidr_block = route.value
      transit_gateway_id = local.shared_infra_tgw_id
    }
  }

  dynamic "route" {
    for_each = local.hitachi_ips.visa.ips
    content {
      cidr_block = route.value
      transit_gateway_id = local.shared_infra_tgw_id
    }
  }

  # route {
  #   cidr_block = data.terraform_remote_state.shared_infra.outputs.ad_private2_cidr
  #   transit_gateway_id = local.shared_infra_tgw_id
  # }

  #  route {
  #   cidr_block = data.terraform_remote_state.shared_infra.outputs.ad_private1_cidr
  #   transit_gateway_id = local.shared_infra_tgw_id
  # }

  # route {
  #   cidr_block = data.terraform_remote_state.shared_infra.outputs.ad_public1_cidr
  #   transit_gateway_id = local.shared_infra_tgw_id
  # }


  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-endpoint-rt"}))
}


resource "aws_route_table_association" "uat_firewall1_egress_rt_association" {
  count = length(local.firewall_egress_subnets)
  subnet_id      = local.firewall_egress_subnets[count.index].id
  route_table_id = aws_route_table.uat_firewall1_egress_rt[count.index].id
}

resource "aws_route_table_association" "uat_firewall1_endpoint_rt_association" {
  count = length(local.firewall_endpoint_subnets)
  subnet_id      = local.firewall_endpoint_subnets[count.index]
  route_table_id = aws_route_table.uat_firewall1_endpoint_rt.id
}

resource "aws_route_table" "uat_firewall1_entrypoint_rt" {
  vpc_id = aws_vpc.uat_infra_1.id

  dynamic route {
    for_each = local.k8s_private_subnets
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

    dynamic route {
    for_each = local.k8s_public_subnets
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

    dynamic route {
    for_each = local.cde_k8s_private_subnets
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }
    dynamic route {
    for_each = local.noncde_k8s_private_subnets
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

  tags = merge(local.tags,tomap({"Name" = "uat-firewall1-entrypoint-rt"}))
}


resource "aws_route_table_association" "uat_firewall1_entrypoint_rt_association" {
  count = length(local.firewall_entrypoint_subnets)
  subnet_id = local.firewall_entrypoint_subnets[count.index]
  route_table_id = aws_route_table.uat_firewall1_entrypoint_rt.id
}

resource "aws_kms_key" "firewall_encrypt" {
  description             = "Key for encrypting firewall data"
  deletion_window_in_days = 10
  key_usage = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
  policy                   = jsonencode(
        {
            Statement = [
      {
        "Sid"= "Allow current account to administer the key"
        "Effect"= "Allow",
         "Principal"= {
        "AWS"= "arn:aws:iam::${var.account_id}:root"
        },
        "Action"= "kms:*",
        "Resource"= "*"
        }
            ]
            Version   = "2012-10-17"
        }
    )
  tags = merge(local.tags,tomap({"Name" = "firewall_encrypt"}))
}
resource "aws_kms_alias" "firewall_encrypt_alias" {
  name          = "alias/firewall_encrypt"
  target_key_id = aws_kms_key.firewall_encrypt.id
}



# aws_networkfirewall_firewall.uat_firewall1:
resource "aws_networkfirewall_firewall" "uat_firewall1" {
    delete_protection                 = true
    description                       = "uat-firewall"
    firewall_policy_change_protection = false
    name                              = "uat-firewall"
    subnet_change_protection          = true
    vpc_id                            = aws_vpc.uat_infra_1.id
    firewall_policy_arn = aws_networkfirewall_firewall_policy.firewallp1.arn

    subnet_mapping {
        subnet_id = aws_subnet.uat_firewall1_endpoint1.id
    }
    subnet_mapping {
        subnet_id = aws_subnet.uat_firewall1_endpoint2.id
    }

  tags = merge(local.tags,tomap({"Name" = "uat-network-firewall"}))
}



# ###########
# #NACL for firewall endpoint
# ###########


# resource "aws_network_acl" "uat_app_k8s_firewall_endpoint_nacl" {
#   vpc_id = aws_vpc.uat_infra_1.id




#   ingress {
#     protocol   = -1
#     rule_no    = 50
#     action     = "allow"
#     cidr_block = "10.0.0.0/8"
#     from_port  = 0
#     to_port    = 0
#   }

#   dynamic "ingress" {
#     for_each = [80, 443]
#     content {
#       protocol   = "tcp"
#       rule_no    = 60 + "${ingress.key}"
#       action     = "allow"
#       cidr_block = "0.0.0.0/0"
#       from_port  = "${ingress.value}"
#       to_port    = "${ingress.value}"
#     }
#   }

#  egress {
#     protocol   = -1
#     rule_no    = 65
#     action     = "allow"
#     cidr_block = "10.0.0.0/8"
#     from_port  = 0
#     to_port    = 0
#   }

#   egress {
#     protocol   = "tcp"
#     rule_no    = 70
#     action     = "allow"
#     cidr_block = "0.0.0.0/0"
#     from_port  = 0
#     to_port    = 65535
#   }

#   tags = {
#     Name = "uat-app-k8s-firewall-endpoint-nacl"
#   }
# }

# locals {
#   uat_app_k8s_firewall_endpoint_subnets = [aws_subnet.uat_firewall1_endpoint1, aws_subnet.uat_firewall1_endpoint2]
# }

# resource "aws_network_acl_association" "app_k8s_firewall_endpoint" {
#   count = length(local.uat_app_k8s_firewall_endpoint_subnets)
#   network_acl_id = aws_network_acl.uat_app_k8s_firewall_endpoint_nacl.id
#   subnet_id      = local.uat_app_k8s_firewall_endpoint_subnets[count.index].id
# }