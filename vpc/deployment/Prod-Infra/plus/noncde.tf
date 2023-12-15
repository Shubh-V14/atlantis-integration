
resource "aws_subnet" "prod_noncde_private1" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.132.0/24"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private1", "kubernetes.io/role/internal-elb" = "1" }))
}

output "prod_noncde_private1_cidr" {
  value = aws_subnet.prod_noncde_private1.cidr_block
}

output "prod_noncde_private1_subnet" {
  value = aws_subnet.prod_noncde_private1
}


resource "aws_subnet" "prod_noncde_private2" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.133.0/24"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private2", "kubernetes.io/role/internal-elb" = "1" }))
}

output "prod_noncde_private2_cidr" {
  value = aws_subnet.prod_noncde_private2.cidr_block
}

output "prod_noncde_private2_subnet" {
  value = aws_subnet.prod_noncde_private2
}


resource "aws_subnet" "prod_noncde_private3" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.130.0/24"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private3", "kubernetes.io/role/internal-elb" = "1" }))
}

output "prod_noncde_private3_cidr" {
  value = aws_subnet.prod_noncde_private3.cidr_block
}

output "prod_noncde_private3_subnet" {
  value = aws_subnet.prod_noncde_private3
}

resource "aws_subnet" "prod_noncde_private4" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.131.0/24"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private4", "kubernetes.io/role/internal-elb" = "1" }))
}

output "prod_noncde_private4_cidr" {
  value = aws_subnet.prod_noncde_private4.cidr_block
}

output "prod_noncde_private4_subnet" {
  value = aws_subnet.prod_noncde_private4
}

resource "aws_subnet" "prod_noncde_private5" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.135.0/24"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private5"}))
}

output "prod_noncde_private5_cidr" {
  value = aws_subnet.prod_noncde_private5.cidr_block
}

output "prod_noncde_private5_subnet" {
  value = aws_subnet.prod_noncde_private5
}

resource "aws_subnet" "prod_noncde_private6" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.136.0/24"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private6"}))
}

output "prod_noncde_private6_cidr" {
  value = aws_subnet.prod_noncde_private6.cidr_block
}

output "prod_noncde_private6_subnet" {
  value = aws_subnet.prod_noncde_private6
}


resource "aws_subnet" "prod_noncde_public1" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.134.0/26"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-public1", "kubernetes.io/role/elb" = "1" }))
}

resource "aws_subnet" "prod_noncde_public2" {
  lifecycle {
    ignore_changes = ["enable_lni_at_device_index"]
  }
  vpc_id     = aws_vpc.prod_noncde_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.134.64/26"

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-public2", "kubernetes.io/role/elb" = "1" }))
}


resource "aws_route_table" "prod_noncde_public_rt" {
  count = length(local.firewall_endpoints)
  vpc_id     = aws_vpc.prod_noncde_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-public-rt-${count.index}"}))
}

locals {
    prod_noncde_public_subnets = [aws_subnet.prod_noncde_public1, aws_subnet.prod_noncde_public2]
    prod_noncde_private_subnets = [aws_subnet.prod_noncde_private1, aws_subnet.prod_noncde_private2]
    prod_noncde_private_subnets_2 = [aws_subnet.prod_noncde_private3, aws_subnet.prod_noncde_private4 ]
    prod_noncde_private_subnets_3 = [aws_subnet.prod_noncde_private5, aws_subnet.prod_noncde_private6]
}

resource "aws_route_table_association" "prod_noncde_public_rt_association2" {
  count = length(local.prod_noncde_public_subnets)
  subnet_id      = local.prod_noncde_public_subnets[count.index].id
  route_table_id = aws_route_table.prod_noncde_public_rt[count.index].id
}



resource "aws_route_table" "prod_noncde_private_rt" {
  count = length(local.firewall_egress_nats)
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


  #connect to db subnet over peering

 route {
    cidr_block = aws_subnet.prod_noncde_db_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
    
  }


 route {
    cidr_block = aws_subnet.prod_noncde_db_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.prod_noncde_db_pc.id
  }

  dynamic "route" {
    for_each = local.utkarsh_cidrs
    content {
      cidr_block = route.value
      vpc_endpoint_id = local.firewall_endpoints[count.index]
    }
  }

  dynamic "route" {
    for_each = local.utkarsh_dr_cidrs
    content {
      cidr_block = route.value
      vpc_endpoint_id = local.firewall_endpoints[count.index]
    }
  }

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-private-rt-${count.index + 1}"}))
}


resource "aws_route_table_association" "prod_noncde_private_rt_association" {
  count = length(local.prod_noncde_private_subnets)
  subnet_id      = local.prod_noncde_private_subnets[count.index].id
  route_table_id = aws_route_table.prod_noncde_private_rt[count.index].id
}

resource "aws_route_table_association" "prod_noncde_private_rt_association_2" {
  count = length(local.prod_noncde_private_subnets_2)
  subnet_id      = local.prod_noncde_private_subnets_2[count.index].id
  route_table_id = aws_route_table.prod_noncde_private_rt[count.index].id
}

resource "aws_route_table_association" "prod_noncde_private_rt_association_3" {
  count = length(local.prod_noncde_private_subnets_3)
  subnet_id      = local.prod_noncde_private_subnets_3[count.index].id
  route_table_id = aws_route_table.prod_noncde_private_rt[count.index].id
}


resource "aws_ram_resource_share" "share_prod_noncde_to_prod_application" {
  name                      = "prod-noncde-share-prod-application"
  allow_external_principals = false

  tags = {
    Environment = "prod"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_prod_noncde_to_prod_application_association" {
  principal          = local.prod_application_account_id
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_to_prod_application.arn
}

resource "aws_ram_resource_association" "share_noncde_private_subnets_to_prod_application" {
  count = length(local.prod_noncde_private_subnets)
  resource_arn       = local.prod_noncde_private_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_to_prod_application.arn
}

resource "aws_ram_resource_association" "share_noncde_private_subnets_2_to_prod_application" {
  count = length(local.prod_noncde_private_subnets_2)
  resource_arn       = local.prod_noncde_private_subnets_2[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_to_prod_application.arn
}

resource "aws_ram_resource_association" "share_noncde_private_subnets_3_to_prod_application" {
  count = length(local.prod_noncde_private_subnets_3)
  resource_arn       = local.prod_noncde_private_subnets_3[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_to_prod_application.arn
}

resource "aws_ram_resource_association" "share_noncde_public_subnets_to_prod_application" {
  count = length(local.prod_noncde_public_subnets)
  resource_arn       = local.prod_noncde_public_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_to_prod_application.arn
}

resource "aws_network_acl" "prod_noncde_private_nacl" {
  vpc_id = aws_vpc.prod_noncde_infra_1.id

  egress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_subnet.prod_noncde_public1.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 54
    action     = "deny"
    cidr_block = aws_subnet.prod_noncde_public1.cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 58
    action     = "allow"
    cidr_block = aws_subnet.prod_noncde_public2.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 59
    action     = "deny"
    cidr_block = aws_subnet.prod_noncde_public2.cidr_block
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

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol   = "tcp"
      rule_no    = 61 + "${ingress.key}"
      action     = "allow"
      cidr_block = aws_subnet.prod_noncde_public1.cidr_block
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  ingress {
    protocol   = -1
    rule_no    = 65
    action     = "deny"
    cidr_block = aws_subnet.prod_noncde_public1.cidr_block
    from_port  = 0
    to_port    = 0
  }

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol   = "tcp"
      rule_no    = 66 + "${ingress.key}"
      action     = "allow"
      cidr_block = aws_subnet.prod_noncde_public2.cidr_block
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  ingress {
    protocol   = -1
    rule_no    = 70
    action     = "deny"
    cidr_block = aws_subnet.prod_noncde_public2.cidr_block
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "prod-noncde-private-nacl"
  }
}

resource "aws_network_acl_association" "noncde_private" {
  count = length(local.prod_noncde_private_subnets)
  network_acl_id = aws_network_acl.prod_noncde_private_nacl.id
  subnet_id      = local.prod_noncde_private_subnets[count.index].id
}

##############

resource "aws_network_acl" "prod_noncde_public_nacl" {
  vpc_id = aws_vpc.prod_noncde_infra_1.id




  ingress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_subnet.prod_noncde_private1.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 51
    action     = "allow"
    cidr_block = aws_subnet.prod_noncde_private2.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  dynamic "ingress" {
    for_each = [80, 443]
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
    Name = "prod-noncde-public-nacl"
  }
}

resource "aws_network_acl_association" "noncde_public" {
  count = length(local.prod_noncde_public_subnets)
  network_acl_id = aws_network_acl.prod_noncde_public_nacl.id
  subnet_id      = local.prod_noncde_public_subnets[count.index].id
}

