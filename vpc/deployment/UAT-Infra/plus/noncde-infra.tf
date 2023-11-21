resource "aws_subnet" "uat_noncde_private1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.62.0/24"

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-private1", "kubernetes.io/role/internal-elb" = "1" }))
}

output "uat_noncde_private1_cidr" {
  value = aws_subnet.uat_noncde_private1.cidr_block
}

output "uat_noncde_private1_subnet" {
  value = aws_subnet.uat_noncde_private1
}

output "uat_noncde_public1_subnet" {
  value = aws_subnet.uat_noncde_public1
}
output "uat_noncde_public2_subnet" {
  value = aws_subnet.uat_noncde_public2
}


resource "aws_subnet" "uat_noncde_private2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.63.0/24"

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-private2", "kubernetes.io/role/internal-elb" = "1" }))
}

output "uat_noncde_private2_cidr" {
  value = aws_subnet.uat_noncde_private2.cidr_block
}

output "uat_noncde_private2_subnet" {
  value = aws_subnet.uat_noncde_private2
}



resource "aws_subnet" "uat_noncde_public1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.57.0/27"

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-public1", "kubernetes.io/role/elb" = "1" }))
}

resource "aws_subnet" "uat_noncde_public2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.57.32/27"

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-public2", "kubernetes.io/role/elb" = "1" }))
}


resource "aws_route_table" "uat_noncde_public_rt" {
  count = length(local.firewall_endpoints)
  vpc_id     = aws_vpc.uat_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-public-rt-${count.index}"}))
}

locals {
    uat_noncde_public_subnets = [aws_subnet.uat_noncde_public1, aws_subnet.uat_noncde_public2]
    uat_noncde_private_subnets = [aws_subnet.uat_noncde_private1, aws_subnet.uat_noncde_private2]
}

resource "aws_route_table_association" "uat_noncde_public_rt_association2" {
  count = length(local.uat_noncde_public_subnets)
  subnet_id      = local.uat_noncde_public_subnets[count.index].id
  route_table_id = aws_route_table.uat_noncde_public_rt[count.index].id
}



resource "aws_route_table" "uat_noncde_private_rt" {
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
    cidr_block = aws_subnet.uat_noncde_db1_private1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
    
  }


 route {
    cidr_block = aws_subnet.uat_noncde_db1_private2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.uat_noncde_db_infra1_pc.id
  }

  dynamic "route" {
    for_each = local.utkarsh_cidrs
    content {
      cidr_block = route.value
      vpc_endpoint_id = local.firewall_endpoints[count.index]
    }
  }

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-private-rt-${count.index + 1}"}))
}


resource "aws_route_table_association" "uat_noncde_private_rt_association" {
  count = length(local.uat_noncde_private_subnets)
  subnet_id      = local.uat_noncde_private_subnets[count.index].id
  route_table_id = aws_route_table.uat_noncde_private_rt[count.index].id
}


resource "aws_ram_resource_association" "share_noncde_private_subnets_to_uat_application" {
  count = length(local.uat_noncde_private_subnets)
  resource_arn       = local.uat_noncde_private_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

resource "aws_ram_resource_association" "share_noncde_public_subnets_to_uat_application" {
  count = length(local.uat_noncde_public_subnets)
  resource_arn       = local.uat_noncde_public_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

resource "aws_network_acl" "uat_noncde_private_nacl" {
  vpc_id = aws_vpc.uat_infra_1.id

  egress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = "10.0.57.0/27"
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 54
    action     = "deny"
    cidr_block = "10.0.57.0/27"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 58
    action     = "allow"
    cidr_block = "10.0.57.32/27"
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 59
    action     = "deny"
    cidr_block = "10.0.57.32/27"
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
      cidr_block = "10.0.57.0/27"
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  ingress {
    protocol   = -1
    rule_no    = 65
    action     = "deny"
    cidr_block = "10.0.57.0/27"
    from_port  = 0
    to_port    = 0
  }

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol   = "tcp"
      rule_no    = 66 + "${ingress.key}"
      action     = "allow"
      cidr_block = "10.0.57.32/27"
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  ingress {
    protocol   = -1
    rule_no    = 70
    action     = "deny"
    cidr_block = "10.0.57.32/27"
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
    Name = "uat-noncde-private-nacl"
  }
}

resource "aws_network_acl_association" "noncde_private" {
  count = length(local.uat_noncde_private_subnets)
  network_acl_id = aws_network_acl.uat_noncde_private_nacl.id
  subnet_id      = local.uat_noncde_private_subnets[count.index].id
}






##############



resource "aws_network_acl" "uat_noncde_public_nacl" {
  vpc_id = aws_vpc.uat_infra_1.id




  ingress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_subnet.uat_noncde_private1.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 51
    action     = "allow"
    cidr_block = aws_subnet.uat_noncde_private2.cidr_block
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
    Name = "uat-noncde-public-nacl"
  }
}

resource "aws_network_acl_association" "noncde_public" {
  count = length(local.uat_noncde_public_subnets)
  network_acl_id = aws_network_acl.uat_noncde_public_nacl.id
  subnet_id      = local.uat_noncde_public_subnets[count.index].id
}