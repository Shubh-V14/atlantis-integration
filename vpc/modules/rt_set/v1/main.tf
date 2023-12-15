variable vpc_id {
    type = string
}

variable tg_routes {
    type = list(map(string))
    default = []
}

variable igw_routes {
    default = []
    type = list(map(string))
}

variable ngw_routes{
    default = []
    type = list(map(string))
}

variable egw_routes {
  default = []
  type = list(map(string))
}

variable peering_routes {
  default = []
  type = list(map(string))
}

variable name {
    type = string
}

variable variant {
  type = string
}

variable subnet_ids {
  type = list(string)
}

variable subnet_count {
  type = number
}

resource "aws_route_table" "main" {
  count = var.subnet_count
  vpc_id     = var.vpc_id

  dynamic "route" {
    for_each = var.tg_routes
    content {
      cidr_block = route.value.cidr_block
      transit_gateway_id = route.value.tgw_id
    }
  }

  dynamic "route" {
    for_each = var.igw_routes
    content {
      cidr_block = route.value.cidr_block
      gateway_id = route.value.igw_id
    }
  }
  dynamic "route" {

    for_each = var.ngw_routes
    content {
      cidr_block = route.value.cidr_block
      nat_gateway_id = route.value.ngw_id
    }
  }

  dynamic "route" {
    for_each = var.egw_routes
    content {
      ipv6_cidr_block = route.value.cidr_block
      egress_only_gateway_id = route.value.egw_id
    }
  }

  dynamic "route" {
    for_each = var.peering_routes
    content {
      cidr_block = route.value.cidr_block
      vpc_peering_connection_id = route.value.peering_connection_id
    }
  }

  tags = {
    Name = "${var.variant}-${var.name}-${count.index}"
    Environment = var.variant
    Terraform = "true"
  }
}

resource "aws_route_table_association" "main" {
  count = var.subnet_count
  subnet_id      = var.subnet_ids[count.index]
  route_table_id = aws_route_table.main[count.index].id
}