resource "aws_subnet" "ad_private1" {
  vpc_id     = local.shared_infra_1_vpc_id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.0.0/27"


  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ad-private1"}))
}

output "ad_private1_cidr" {
  value = aws_subnet.ad_private1.cidr_block
}


resource "aws_subnet" "ad_private2" {
  vpc_id     = local.shared_infra_1_vpc_id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.0.32/27"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ad-private2"}))
}

output "ad_private2_cidr" {
  value = aws_subnet.ad_private2.cidr_block
}


resource "aws_internet_gateway" "ad_igw" {
  vpc_id = local.shared_infra_1_vpc_id

  tags = {
    Name = "ad-igw"
    Environment = "shared"
    Terraform = "true"
  }
}

# resource "aws_subnet" "ad_public1" {
#   vpc_id     = local.shared_infra_1_vpc_id
#   availability_zone_id = "aps1-az1"
#   cidr_block = "10.0.0.64/27"
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "ad-public1"
#     Environment = "shared"
#     Terraform = "true"
#   }
# }

# output "ad_public1_cidr" {
#   value = aws_subnet.ad_public1.cidr_block
# }

# resource "aws_route_table" "ad_public1_rt" {
#   vpc_id     = local.shared_infra_1_vpc_id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.ad_igw.id
#   }

#   route {
#     cidr_block = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_cidr
#     transit_gateway_id = module.tgw.ec2_transit_gateway_id
#   }

#   tags = {
#     Name = "ad-public1-rt"
#     Environment = "shared"
#     Terraform = "true"
#   }
# }

# resource "aws_route_table_association" "ad_public1_rt_association" {
#   subnet_id      = aws_subnet.ad_public1.id
#   route_table_id = aws_route_table.ad_public1_rt.id
# }

resource "aws_route_table" "ad_private_rt" {
  vpc_id     = local.shared_infra_1_vpc_id


  tags = {
    Name = "ad-private-rt"
    Environment = "shared"
    Terraform = "true"
  }

  route {
    cidr_block = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_cidr
    transit_gateway_id = module.tgw.ec2_transit_gateway_id
  }
}

resource "aws_route_table_association" "ad_private_rt_association1" {
  subnet_id      = aws_subnet.ad_private1.id
  route_table_id = aws_route_table.ad_private_rt.id
}

resource "aws_route_table_association" "ad_private_rt_association2" {
  subnet_id      = aws_subnet.ad_private2.id
  route_table_id = aws_route_table.ad_private_rt.id
}

# variable "corp_upswing_internal_password" {
#   description = "password for corp.upswing.internal directory password"
#   type        = string
#   sensitive   = true
# }

# # aws_directory_service_directory.corp_upswing_internal:
# resource "aws_directory_service_directory" "corp_upswing_internal" {
#     alias             = "up-swing"
#     description       = "corp.upswing.internal"
#     password          = var.corp_upswing_internal_password
#     edition           = "Standard"
#     enable_sso        = false
#     name              = "corp.upswing.internal"
#     short_name        = "corp"
#     size              = "Small"
#     tags              = {}
#     tags_all          = {}
#     type              = "MicrosoftAD"

#     vpc_settings {
#         subnet_ids         = [
#             aws_subnet.ad_private1.id,
#             aws_subnet.ad_private2.id
#         ]
#         vpc_id             = local.shared_infra_1_vpc_id
#     }
# }

