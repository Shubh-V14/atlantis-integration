resource "aws_subnet" "uat_cde_private1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.60.0/24"

  tags = merge(local.tags,tomap({"Name" = "uat-cde-private1", "kubernetes.io/role/internal-elb" = "1" }))
}

output "uat_cde_private1_cidr" {
  value = aws_subnet.uat_cde_private1.cidr_block
}

output "uat_cde_private1_subnet" {
  value = aws_subnet.uat_cde_private1
}


resource "aws_subnet" "uat_cde_private2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.61.0/24"

  tags = merge(local.tags,tomap({"Name" = "uat-cde-private2", "kubernetes.io/role/internal-elb" = "1" }))
}

output "uat_cde_private2_cidr" {
  value = aws_subnet.uat_cde_private2.cidr_block
}

output "uat_cde_private2_subnet" {
  value = aws_subnet.uat_cde_private2
}


resource "aws_subnet" "uat_cde_public1" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.56.192/27"

  tags = merge(local.tags,tomap({"Name" = "uat-cde-public1", "kubernetes.io/role/elb" = "1" }))
}

resource "aws_subnet" "uat_cde_public2" {
  vpc_id     = aws_vpc.uat_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.56.224/27"

  tags = merge(local.tags,tomap({"Name" = "uat-cde-public2", "kubernetes.io/role/elb" = "1" }))
}

output "uat_cde_public1_subnet" {
  value = aws_subnet.uat_cde_public1
}
output "uat_cde_public2_subnet" {
  value = aws_subnet.uat_cde_public2
}


locals {
  allowed_local_subnets = [aws_subnet.uat_cde_public1, aws_subnet.uat_cde_public2, aws_subnet.uat_cde_private1, aws_subnet.uat_cde_private2, aws_subnet.uat_app_k8s_private1, aws_subnet.uat_app_k8s_private2, aws_subnet.uat_app_k8s_public1, aws_subnet.uat_app_k8s_public2, aws_subnet.uat_firewall1_endpoint1, aws_subnet.uat_firewall1_endpoint2, aws_subnet.uat_firewall1_entrypoint1, aws_subnet.uat_firewall1_entrypoint2, aws_subnet.uat_firewall1_egress1, aws_subnet.uat_firewall1_egress2]
}



data "aws_subnets" "uat_infra" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.uat_infra_1.id]
  }
}

data "aws_subnet" "uat_infra" {
  for_each = toset(data.aws_subnets.uat_infra.ids)
  id       = each.value
}


locals {
 all_subnet_cidr_blocks = [for s in data.aws_subnet.uat_infra : s.cidr_block]
 allowed_local_subnets_cidr_blocks = [for s in local.allowed_local_subnets: s.cidr_block]
 subnets_to_block = [
    for x in local.all_subnet_cidr_blocks : x if !contains(local.allowed_local_subnets_cidr_blocks, x)
  ]
}

output "subnets_to_block" {
  value = local.subnets_to_block
}

output "allowed_local_subnets" {
  value = local.allowed_local_subnets_cidr_blocks
}

locals {
  public_cde_subnets =  [aws_subnet.uat_cde_public1, aws_subnet.uat_cde_public2]
  private_cde_subnets =  [aws_subnet.uat_cde_private1, aws_subnet.uat_cde_private2]
}

resource "aws_network_interface" "blackhole_public" {
  count = length(local.public_cde_subnets)
  subnet_id       = local.public_cde_subnets[count.index].id
  security_groups = ["sg-0f6f0a23efddf11f8"]
}

resource "aws_network_interface" "blackhole_private" {
  count = length(local.private_cde_subnets)
  subnet_id       = local.private_cde_subnets[count.index].id
  security_groups = ["sg-0f6f0a23efddf11f8"]
}
resource "aws_route_table" "uat_cde_public_rt" {
  count = length(local.public_cde_subnets)
  vpc_id     = aws_vpc.uat_infra_1.id


  dynamic "route" {
    for_each = local.subnets_to_block
    content  {
      cidr_block = route.value
      network_interface_id = aws_network_interface.blackhole_public[count.index].id
    }
  }

  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[count.index]
  }

  tags = merge(local.tags,tomap({"Name" = "uat-cde-public-rt-${count.index}"}))
}

locals {
    uat_cde_public_subnets = [aws_subnet.uat_cde_public1, aws_subnet.uat_cde_public2]
    uat_cde_private_subnets = [aws_subnet.uat_cde_private1, aws_subnet.uat_cde_private2]
}

resource "aws_route_table_association" "uat_cde_public_rt_association2" {
  count = length(local.uat_cde_public_subnets)
  subnet_id      = local.uat_cde_public_subnets[count.index].id
  route_table_id = aws_route_table.uat_cde_public_rt[count.index].id
}



resource "aws_route_table" "uat_cde_private_rt" {
  count = length(local.firewall_egress_nats)
  vpc_id     = aws_vpc.uat_infra_1.id

  dynamic "route" {
    for_each = local.subnets_to_block
    content  {
      cidr_block = route.value
      network_interface_id = aws_network_interface.blackhole_private[count.index].id
    }
  }

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
    cidr_block = aws_subnet.uat_cde_db1_private1.cidr_block
    vpc_peering_connection_id = local.uat_infra1_db1_pc_id
  }


 route {
    cidr_block = aws_subnet.uat_cde_db1_private2.cidr_block
    vpc_peering_connection_id = local.uat_infra1_db1_pc_id
  }


  dynamic "route" {
    for_each = local.hitachi_ips.visa.ips
    content {
      cidr_block = route.value
      vpc_endpoint_id = local.firewall_endpoints[count.index]
    }
  }

  tags = merge(local.tags,tomap({"Name" = "uat-cde-private-rt-${count.index + 1}"}))
}

resource "aws_route_table_association" "uat_cde_private_rt_association" {
  count = length(local.uat_cde_private_subnets)
  subnet_id      = local.uat_cde_private_subnets[count.index].id
  route_table_id = aws_route_table.uat_cde_private_rt[count.index].id
}

resource "aws_ram_resource_association" "share_cde_private_subnets_to_uat_application" {
  count = length(local.uat_cde_private_subnets)
  resource_arn       = local.uat_cde_private_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

resource "aws_ram_resource_association" "share_cde_public_subnets_to_uat_application" {
  count = length(local.uat_cde_public_subnets)
  resource_arn       = local.uat_cde_public_subnets[count.index].arn
  resource_share_arn = aws_ram_resource_share.share_infra_to_uat_application.arn
}

resource "aws_network_acl" "uat_cde_private_nacl" {
  vpc_id = aws_vpc.uat_infra_1.id

  egress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_subnet.uat_cde_public1.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 54
    action     = "deny"
    cidr_block = aws_subnet.uat_cde_public1.cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "tcp"
    rule_no    = 58
    action     = "allow"
    cidr_block = aws_subnet.uat_cde_public2.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  egress {
    protocol   = -1
    rule_no    = 59
    action     = "deny"
    cidr_block = aws_subnet.uat_cde_public2.cidr_block
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
      cidr_block = aws_subnet.uat_cde_public1.cidr_block
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  ingress {
    protocol   = -1
    rule_no    = 65
    action     = "deny"
    cidr_block = aws_subnet.uat_cde_public1.cidr_block
    from_port  = 0
    to_port    = 0
  }

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol   = "tcp"
      rule_no    = 66 + "${ingress.key}"
      action     = "allow"
      cidr_block = aws_subnet.uat_cde_public2.cidr_block
      from_port  = "${ingress.value}"
      to_port    = "${ingress.value}"
    }
  }

  ingress {
    protocol   = -1
    rule_no    = 70
    action     = "deny"
    cidr_block = aws_subnet.uat_cde_public2.cidr_block
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
    Name = "uat-cde-private-nacl"
  }
}

resource "aws_network_acl_association" "cde_private" {
  count = length(local.uat_cde_private_subnets)
  network_acl_id = aws_network_acl.uat_cde_private_nacl.id
  subnet_id      = local.uat_cde_private_subnets[count.index].id
}



resource "aws_network_acl" "uat_cde_public_nacl" {
  vpc_id = aws_vpc.uat_infra_1.id




  ingress {
    protocol   = "tcp"
    rule_no    = 50
    action     = "allow"
    cidr_block = aws_subnet.uat_cde_private1.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 51
    action     = "allow"
    cidr_block = aws_subnet.uat_cde_private2.cidr_block
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
    Name = "uat-cde-public-nacl"
  }
}

resource "aws_network_acl_association" "cde_public" {
  count = length(local.uat_cde_public_subnets)
  network_acl_id = aws_network_acl.uat_cde_public_nacl.id
  subnet_id      = local.uat_cde_public_subnets[count.index].id
}