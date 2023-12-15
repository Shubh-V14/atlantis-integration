variable allowed_cidrs {
  type = list(string)
}

variable name {
  type = string
}

variable variant {
  type = string
}

variable vpc_id {
  type = string
}

resource "aws_security_group" "main" {
    description = "Communication between the control plane and worker nodegroups"
    egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    ingress     = [
        {
            cidr_blocks      = var.allowed_cidrs
            description      = ""
            from_port        = 443
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 443
        },
    ]
    tags = {
      Name = "${var.variant}-${var.name}"
      Environment = var.variant
      Terraform = "true"
    }
    tags_all    = {}
    vpc_id      = var.vpc_id
    timeouts {}
      lifecycle {
    ignore_changes = [
      egress,
      ingress
    ]
  }
}

output sg_id {
  value = aws_security_group.main.
}