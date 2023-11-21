variable cidrs {
    type = list(string)
}

variable vpc_id  {
    type = string
}

variable az_prefix {
    type = string
}

variable name {
    type = string
}

variable variant {
    type = string
}

variable tags {
    type = map(string)
    default = {}
}

variable ipv6_cidr_block {
    type = list(string)
    default = []
}

resource "aws_subnet" "main" {
  count = length(var.cidrs)
  vpc_id     = var.vpc_id
  availability_zone_id = "${var.az_prefix}-az${count.index+1}"
  cidr_block = var.cidrs[count.index]
  ipv6_cidr_block = length(var.ipv6_cidr_block) == 0 ? null : var.ipv6_cidr_block[count.index]
  assign_ipv6_address_on_creation = length(var.ipv6_cidr_block) != 0

  tags = merge({
    Name = "${var.variant}-${var.name}-${count.index}"
    Environment = var.variant
    Terraform = "true"
  }, var.tags)
}

output subnet_ids {
    value = aws_subnet.main[*].id
}

output subnet_arns {
    value = aws_subnet.main[*].arn
}

output subnet_cidrs {
    value = aws_subnet.main[*].cidr_block
}