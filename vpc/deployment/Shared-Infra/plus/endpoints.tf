resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.shared_infra_1.id
  service_name = "com.amazonaws.ap-south-1.s3"
  route_table_ids = [aws_route_table.ad_private_rt.id]

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "s3-endpoint"}))
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.shared_infra_1.id
  service_name = "com.amazonaws.ap-south-1.dynamodb"
  route_table_ids = [aws_route_table.ad_private_rt.id]
  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "dynamodb-endpoint"}))
}

resource "aws_security_group" "ssm_sg" {
    description = "Communication between vpc and ssm service"
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
            cidr_blocks      = [
               aws_vpc.shared_infra_1.cidr_block
            ]
            description      = "allow ssm port from vpc cidr"
            from_port        = 443
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 443
        },
    ]

    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-ssm-sg"}))
    vpc_id      = aws_vpc.shared_infra_1.id
    timeouts {}
}

locals {
    interface_endpoint_services = toset(["ssm", "ec2messages", "ssmmessages", "kms"])
}

resource "aws_vpc_endpoint" "interface_endpoint" {
  for_each = local.interface_endpoint_services
  vpc_id       = aws_vpc.shared_infra_1.id
  service_name = "com.amazonaws.ap-south-1.${each.key}"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.ssm_sg.id
  ]

  private_dns_enabled = true

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "${each.key}-interface-endpoint"}))
}


resource "aws_vpc_endpoint_subnet_association" "interface_endpoint_subnet_association" {
  for_each = aws_vpc_endpoint.interface_endpoint
  vpc_endpoint_id = each.value.id
  subnet_id       = aws_subnet.ad_private1.id
}