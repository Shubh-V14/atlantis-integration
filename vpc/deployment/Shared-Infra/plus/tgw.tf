locals {
  shared_infra_vpc1_id = "vpc-084d78d6928b79232"
}
resource "aws_subnet" "shared_infra_tgw_private1" {
  vpc_id     = local.shared_infra_vpc1_id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.0.160/27"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-tgw-private1"}))
}

resource "aws_subnet" "shared_infra_tgw_private2" {
  vpc_id     = local.shared_infra_vpc1_id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.0.192/27"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-tgw-private2"}))
}

resource "aws_subnet" "shared_infra_public1" {
  vpc_id     = local.shared_infra_vpc1_id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.0.224/27"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-public1"}))
}


# resource "aws_eip" "shared_infra_eip1" {
#   vpc= true

#   tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-eip1"}))
# }

resource "aws_route_table" "shared_infra1_public_rt" {
  vpc_id     = local.shared_infra_vpc1_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "igw-04ec7e5f5364b0ff7"
  }


  tags = merge(local.sprinto_nonprod_tags,tomap({"Name" = "shared-infra-public-rt"}))
}

resource "aws_route_table_association" "shared_infra_public_rt_association1" {
  subnet_id      = aws_subnet.shared_infra_public1.id
  route_table_id = aws_route_table.shared_infra1_public_rt.id
}

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  version = "~> 2.0"

  name        = "ups-tgw"
  description = "Tgw for internall comm"
  ram_allow_external_principals = true

  enable_auto_accept_shared_attachments = true
  enable_default_route_table_association = false
  enable_default_route_table_propagation = false

  vpc_attachments = {
    vpc = {
      vpc_id       = "vpc-084d78d6928b79232" #share_infra_vpc1
      subnet_ids   = [aws_subnet.shared_infra_tgw_private1.id, aws_subnet.shared_infra_tgw_private2.id]
      dns_support  = true
      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false


    }
  }


  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "internal-comm"}))
}

output "ups_tgw_id" {
  value = module.tgw.ec2_transit_gateway_id
}
output "ups_tgw_rt_id" {
  value = module.tgw.ec2_transit_gateway_route_table_id
}

locals {
  shared_infra_tgw_id = module.tgw.ec2_transit_gateway_id
}


resource "aws_ram_principal_association" "org_principal" {
  principal          = "arn:aws:organizations::895788920478:organization/o-azxhqqakdc"
  resource_share_arn = module.tgw.ram_resource_share_id
}


resource "aws_ec2_transit_gateway_route_table_propagation" "propagate_routes_for_stage_app_k8s_to_tgw" {
  transit_gateway_attachment_id  = "tgw-attach-0697b7508244f3e9b"
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_association" "associate_for_stage_app_k8s_to_tgw" {
  transit_gateway_attachment_id  = "tgw-attach-0697b7508244f3e9b"
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_association" "associate_for_uat_app_k8s_to_tgw" {
  transit_gateway_attachment_id  = local.uat_infra_vpc_tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propagate_routes_for_uat_app_k8s_to_tgw" {
  transit_gateway_attachment_id  = local.uat_infra_vpc_tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propagate_routes_for_upswing_stage_app_k8s_to_tgw" {
  transit_gateway_attachment_id  = "tgw-attach-062157c99d7695a3e"
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_association" "associate_for_upswing_stage_app_k8s_to_tgw" {
  transit_gateway_attachment_id  = "tgw-attach-062157c99d7695a3e"
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}


##Share TGW with external accounts

locals {
  external_accounts = [lookup(var.account_mapping, "Upswing-Stage-Infra", 0),lookup(var.account_mapping, "Stage-Infra", 0),lookup(var.account_mapping, "UAT-Infra", 0)]
}

resource "aws_ram_resource_share" "tgw_sender_share" {
  name                      = "tf-external-share"
  allow_external_principals = true

  tags = {
    Name = "tf-external-share"
  }
}
resource "aws_ram_principal_association" "tgw_sender_invite" {
  for_each = toset(local.external_accounts)
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw_sender_share.arn
}
resource "aws_ram_resource_association" "tgw_external_share_association" {
  resource_arn       = module.tgw.ec2_transit_gateway_arn
  resource_share_arn = aws_ram_resource_share.tgw_sender_share.arn
}

output "tgw_external_share_arns" {
  value = aws_ram_principal_association.tgw_sender_invite
}