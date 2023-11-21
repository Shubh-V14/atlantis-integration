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
   tags = {
      Environment = "prod"
      Name        = "firewall_encrypt"
    }
}
resource "aws_kms_alias" "firewall_encrypt_alias" {
  name          = "alias/firewall_encrypt"
  target_key_id = aws_kms_key.firewall_encrypt.id
}

##############

resource "aws_subnet" "prod_noncde_firewall1_endpoint1" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.129.32/28"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-endpoint1"}))
  depends_on = [
    aws_vpc.prod_noncde_infra_1
  ]
}

resource "aws_subnet" "prod_noncde_firewall1_endpoint2" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.129.48/28"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-endpoint2"}))
}

resource "aws_subnet" "prod_noncde_firewall1_egress1" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.129.64/28"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-egress1"}))
}

resource "aws_subnet" "prod_noncde_firewall1_egress2" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.129.80/28"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-egress2"}))
}

output "prod_noncde_firewall1_endpoint1_cidr" {
  value = aws_subnet.prod_noncde_firewall1_endpoint1.cidr_block
}

output "prod_noncde_firewall1_endpoint2_cidr" {
  value = aws_subnet.prod_noncde_firewall1_endpoint2.cidr_block
}

resource "aws_subnet" "prod_noncde_firewall1_entrypoint1" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.129.0/28"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-entrypoint1"}))
}

resource "aws_subnet" "prod_noncde_firewall1_entrypoint2" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.129.16/28"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-entrypoint2"}))
}


resource "aws_eip" "prod_noncde_firewall_eip1" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall-eip1"}))
}

resource "aws_eip" "prod_noncde_firewall_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall-eip2"}))
}

resource "aws_nat_gateway" "prod_noncde_firewall1_ngw1" {
  allocation_id = aws_eip.prod_noncde_firewall_eip1.id
  subnet_id     = aws_subnet.prod_noncde_firewall1_egress1.id

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-NAT1"}))

  depends_on = [aws_internet_gateway.prod_noncde_igw1]
}

resource "aws_nat_gateway" "prod_noncde_firewall1_ngw2" {
  allocation_id = aws_eip.prod_noncde_firewall_eip2.id
  subnet_id     = aws_subnet.prod_noncde_firewall1_egress2.id

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-NAT2"}))
  depends_on = [aws_internet_gateway.prod_noncde_igw1]
}

locals {
    vpce_ap-south-1a = [for ss in aws_networkfirewall_firewall.prod_noncde_firewall1.firewall_status[0].sync_states : ss.attachment[0].endpoint_id if ss.availability_zone == "ap-south-1a"] [0]
    vpce_ap-south-1c = [for ss in aws_networkfirewall_firewall.prod_noncde_firewall1.firewall_status[0].sync_states : ss.attachment[0].endpoint_id if ss.availability_zone == "ap-south-1c"][0]
    firewall_endpoints = [local.vpce_ap-south-1a, local.vpce_ap-south-1c]
    firewall_endpoint_subnets = [aws_subnet.prod_noncde_firewall1_endpoint1, aws_subnet.prod_noncde_firewall1_endpoint2]
    firewall_egress_subnets = [aws_subnet.prod_noncde_firewall1_egress1, aws_subnet.prod_noncde_firewall1_egress2]
    firewall_entrypoint_subnets = [aws_subnet.prod_noncde_firewall1_entrypoint1, aws_subnet.prod_noncde_firewall1_entrypoint2]
    firewall_egress_nats = [aws_nat_gateway.prod_noncde_firewall1_ngw1, aws_nat_gateway.prod_noncde_firewall1_ngw2]
}

resource "aws_route_table" "prod_noncde_firewall1_egress_rt" {
  count = length(local.firewall_endpoints)
  vpc_id     = aws_vpc.prod_noncde_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-egress-rt1"}))
}





resource "aws_route_table" "prod_noncde_firewall1_endpoint_rt" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_noncde_igw1.id
  }

  route {
    cidr_block = aws_subnet.clientvpn_private1.cidr_block
    transit_gateway_id = module.tgw.ec2_transit_gateway_id
  }

  route {
    cidr_block = aws_subnet.clientvpn_private2.cidr_block
    transit_gateway_id = module.tgw.ec2_transit_gateway_id
  }

  dynamic "route" {
    for_each = local.utkarsh_cidrs
    content {
      cidr_block = route.value
      transit_gateway_id = module.tgw.ec2_transit_gateway_id
    }
  }

  dynamic "route" {
    for_each = local.utkarsh_dr_cidrs
    content {
      cidr_block = route.value
      transit_gateway_id = module.tgw.ec2_transit_gateway_id
    }
  }

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-endpoint-rt"}))
}


resource "aws_route_table_association" "prod_noncde_firewall1_egress_rt_association" {
  count = length(local.firewall_egress_subnets)
  subnet_id      = local.firewall_egress_subnets[count.index].id
  route_table_id = aws_route_table.prod_noncde_firewall1_egress_rt[count.index].id
}

resource "aws_route_table_association" "prod_noncde_firewall1_endpoint_rt_association" {
  count = length(local.firewall_endpoint_subnets)
  subnet_id      = local.firewall_endpoint_subnets[count.index].id
  route_table_id = aws_route_table.prod_noncde_firewall1_endpoint_rt.id
}

resource "aws_route_table" "prod_noncde_firewall1_entrypoint_rt" {
  vpc_id = aws_vpc.prod_noncde_infra_1.id

  dynamic route {
    for_each = local.prod_k8s_cluster_private_subnets
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

  dynamic route {
    for_each = local.prod_noncde_private_subnets
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

   dynamic route {
    for_each = local.prod_noncde_private_subnets_2
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }
   dynamic route {
    for_each = local.prod_noncde_private_subnets_3
    content  {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }


  tags = merge(local.tags,tomap({"Name" = "prod-noncde-firewall1-entrypoint-rt"}))
}


resource "aws_route_table_association" "prod_noncde_firewall1_entrypoint_rt_association" {
  count = length(local.firewall_entrypoint_subnets)
  subnet_id = local.firewall_entrypoint_subnets[count.index].id
  route_table_id = aws_route_table.prod_noncde_firewall1_entrypoint_rt.id
}

# aws_networkfirewall_firewall.prod_noncde_firewall1:
resource "aws_networkfirewall_firewall" "prod_noncde_firewall1" {
    delete_protection                 = true
    description                       = "prod-noncde-firewall"
    firewall_policy_change_protection = false
    name                              = "prod-noncde-firewall"
    subnet_change_protection          = true
    vpc_id                            = aws_vpc.prod_noncde_infra_1.id
    firewall_policy_arn = aws_networkfirewall_firewall_policy.firewallp1.arn

    subnet_mapping {
        subnet_id = aws_subnet.prod_noncde_firewall1_endpoint1.id
    }
    subnet_mapping {
        subnet_id = aws_subnet.prod_noncde_firewall1_endpoint2.id
    }

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-network-firewall"}))
}







