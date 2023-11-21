
resource "aws_vpc" "prod_tgw1" {
  ipv4_ipam_pool_id = "ipam-pool-028cadfba5189b4e6"
  cidr_block       = "10.0.192.64/26"
  instance_tenancy = "default"

  tags = {
    Name = "prod-tgw1"
    Environment = "prod"
    Terraform = "true"
  }
}

locals {
  prod_tgw1_id = aws_vpc.prod_tgw1.id
}


resource "aws_subnet" "prod_tgw1_private1" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = local.prod_tgw1_id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.192.64/28"

  tags = merge(local.tags,tomap({"Name" = "prod-tgw-private1"}))
}

resource "aws_subnet" "prod_tgw1_private2" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = local.prod_tgw1_id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.192.80/28"

  tags = merge(local.tags,tomap({"Name" = "prod-tgw-private2"}))
}

resource "aws_subnet" "prod_tgw1_entrypoint1" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = local.prod_tgw1_id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.192.96/28"

  tags = merge(local.tags,tomap({"Name" = "prod-tgw-entrypoint1"}))
}

resource "aws_subnet" "prod_tgw1_entrypoint2" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = local.prod_tgw1_id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.192.112/28"

  tags = merge(local.tags,tomap({"Name" = "prod-tgw-entrypoint2"}))
}

locals {
  prod_tgw1_entrypoint_subnets = [aws_subnet.prod_tgw1_entrypoint1, aws_subnet.prod_tgw1_entrypoint2]
  prod_tgw1_private_subnets = [aws_subnet.prod_tgw1_private1, aws_subnet.prod_tgw1_private2]
}

resource "aws_nat_gateway" "prod_tgw1_private_nat" {
  count = length(local.prod_tgw1_private_subnets)
  connectivity_type = "private"
  subnet_id         = local.prod_tgw1_private_subnets[count.index].id
}

resource "aws_route_table" "prod_tgw1_entrypoint_rt" {
  count = length(local.prod_tgw1_entrypoint_subnets)
  vpc_id     = aws_vpc.prod_tgw1.id

  dynamic "route" {
    for_each = local.utkarsh_cidrs
    content {
      cidr_block = route.value
      nat_gateway_id = aws_nat_gateway.prod_tgw1_private_nat[count.index].id
    }
  }

   dynamic "route" {
    for_each = local.utkarsh_dr_cidrs
    content {
      cidr_block = route.value
      nat_gateway_id = aws_nat_gateway.prod_tgw1_private_nat[count.index].id
    }
  }
  tags = merge(local.tags,tomap({"Name" = "prod-tgw-entrypoint-rt-${count.index}"}))
}

resource "aws_route_table" "prod_tgw1_private_rt" {
  count = length(local.prod_tgw1_private_subnets)
  vpc_id     = aws_vpc.prod_tgw1.id

  dynamic "route" {
    for_each = local.prod_noncde_private_subnets
    content {
      cidr_block = route.value.cidr_block
      transit_gateway_id = module.tgw.ec2_transit_gateway_id
    }
  }

  dynamic "route" {
    for_each = local.prod_noncde_private_subnets_2
    content {
      cidr_block = route.value.cidr_block
      transit_gateway_id = module.tgw.ec2_transit_gateway_id
    }
  }

  dynamic "route" {
    for_each = local.prod_noncde_private_subnets_3
    content {
      cidr_block = route.value.cidr_block
      transit_gateway_id = module.tgw.ec2_transit_gateway_id
    }
  }

  dynamic "route" {
    for_each = local.utkarsh_cidrs
    content {
      cidr_block = route.value
      gateway_id = "vgw-08cbfed5dcc04bc2c"
    }
    }

  # dynamic "route" {
  #   for_each = local.utkarsh_dr_cidrs
  #   content {
  #     cidr_block = route.value
  #     gateway_id = "vgw-05c53112e5aa0e66e"
  #   }
  # }



  tags = merge(local.tags,tomap({"Name" = "prod-tgw-private-rt-${count.index}"}))
}

resource "aws_route_table_association" "prod_tgw_entrypoint_rt_association" {
  count = length(local.prod_tgw1_entrypoint_subnets)
  subnet_id      = local.prod_tgw1_entrypoint_subnets[count.index].id
  route_table_id = aws_route_table.prod_tgw1_entrypoint_rt[count.index].id
}

resource "aws_route_table_association" "prod_tgw_private_rt_association" {
  count = length(local.prod_tgw1_private_subnets)
  subnet_id      = local.prod_tgw1_private_subnets[count.index].id
  route_table_id = aws_route_table.prod_tgw1_private_rt[count.index].id
}

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 2.0"

  name        = "ups-tgw"
  description = "Tgw for internall comm"

  enable_auto_accept_shared_attachments = true
  enable_default_route_table_association = false
  enable_default_route_table_propagation = false

  tags = merge(local.tags,tomap({"Name" = "internal-comm"}))
}

output "ups_tgw_id" {
  value = module.tgw.ec2_transit_gateway_id
}
output "ups_tgw_rt_id" {
  value = module.tgw.ec2_transit_gateway_route_table_id
}


resource "aws_ec2_transit_gateway_vpc_attachment" "prod_noncde_clientvpn" {
  subnet_ids         = local.client_vpn_subnets[*].id
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = aws_vpc.prod_noncde_clientvpn.id
  appliance_mode_support = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}



resource "aws_ec2_transit_gateway_vpc_attachment" "prod_noncde_infra" {
  subnet_ids         = local.firewall_entrypoint_subnets[*].id
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = aws_vpc.prod_noncde_infra_1.id
  appliance_mode_support = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod_tgw" {
  subnet_ids         = local.prod_tgw1_entrypoint_subnets[*].id
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = aws_vpc.prod_tgw1.id
  appliance_mode_support = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}


resource "aws_ec2_transit_gateway_route_table" "prod_noncde_infra_route_table" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
}

locals {
  client_vpn_subnets=[aws_subnet.clientvpn_private1, aws_subnet.clientvpn_private2]
  prod_k8s_cluster_private_cidrs = [aws_subnet.prod_k8s_cluster_private1.cidr_block, aws_subnet.prod_k8s_cluster_private2.cidr_block]
}

resource "aws_ec2_transit_gateway_route" "prod_k8s_cluster_private" {
  count = length(local.prod_k8s_cluster_private_cidrs)
  destination_cidr_block         = local.prod_k8s_cluster_private_cidrs[count.index]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_infra.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route" "prod_k8s_noncde_private" {
  count = length(local.prod_noncde_private_subnets)
  destination_cidr_block         = local.prod_noncde_private_subnets[count.index].cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_infra.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route" "prod_k8s_noncde_private_2" {
  count = length(local.prod_noncde_private_subnets_2)
  destination_cidr_block         = local.prod_noncde_private_subnets_2[count.index].cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_infra.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route" "prod_k8s_noncde_private_3" {
  count = length(local.prod_noncde_private_subnets_3)
  destination_cidr_block         = local.prod_noncde_private_subnets_3[count.index].cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_infra.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}


 resource "aws_ec2_transit_gateway_route" "route_client_vpn_to_prod_infra" {
  count = length(local.client_vpn_subnets)
  destination_cidr_block         = local.client_vpn_subnets[count.index].cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_clientvpn.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}


resource "aws_ec2_transit_gateway_route_table_association" "prod_noncde_client_vpn_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_clientvpn.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route_table_association" "prod_noncde_infra_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_noncde_infra.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}


resource "aws_ec2_transit_gateway_route_table_association" "prod_tgw1_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_tgw.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "prod_tgw1_propagation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_tgw.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route" "utkarsh_routes" {
  count = length(local.utkarsh_cidrs)
  destination_cidr_block         = local.utkarsh_cidrs[count.index]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_tgw.id
  transit_gateway_route_table_id =aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}

resource "aws_ec2_transit_gateway_route" "utkarsh_dr_routes" {
  count = length(local.utkarsh_dr_cidrs)
  destination_cidr_block         = local.utkarsh_dr_cidrs[count.index]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod_tgw.id
  transit_gateway_route_table_id =aws_ec2_transit_gateway_route_table.prod_noncde_infra_route_table.id
}