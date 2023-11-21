locals {
    uat_infra_vpc1_name = "uat-infra1"
    uat_infra_vpc1_cidr = "10.0.48.0/20"
    tags = {
      Environment = "uat"
      Terraform = "true"
      sprinto = "Prod" 
    }
}


data "terraform_remote_state" "shared_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Shared-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

locals {
  shared_infra_1_vpc_id = data.terraform_remote_state.shared_infra.outputs.shared_infra_1_id
  shared_infra_tgw_id = data.terraform_remote_state.shared_infra.outputs.ups_tgw_id
  shared_infra_clientvpn_private1_sub_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private1_sub_cidr
  shared_infra_clientvpn_private2_sub_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private2_sub_cidr
}

resource "aws_ram_resource_share_accepter" "accept_tgw_from_shared_infra" {
  share_arn = data.terraform_remote_state.shared_infra.outputs.tgw_external_share_arns["${var.account_id}"]["resource_share_arn"]
}

resource "aws_vpc" "uat_infra_1" {
  ipv4_ipam_pool_id = "ipam-pool-0b199f5a6a437ea04"
  cidr_block       = local.uat_infra_vpc1_cidr
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = merge(local.tags,tomap({"Name" = "uat-infra-1"}))

}

output "vpc_uat_infra_1_id" {
  value = aws_vpc.uat_infra_1.id
}

output "vpc_uat_infra_1_cidr" {
  value = aws_vpc.uat_infra_1.cidr_block
}

# resource "aws_security_group" "uat_app_k8s_sg1" {
#     description = "Communication between the control plane and worker nodegroups"
#     egress      = [
#         {
#             cidr_blocks      = [
#                 "0.0.0.0/0",
#             ]
#             description      = ""
#             from_port        = 0
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "-1"
#             security_groups  = []
#             self             = false
#             to_port          = 0
#         },
#     ]
#     ingress     = [
#         {
#             cidr_blocks      = [
#                 local.shared_infra_clientvpn_private1_sub_cidr,
#                 local.shared_infra_clientvpn_private2_sub_cidr
#             ]
#             description      = ""
#             from_port        = 443
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "tcp"
#             security_groups  = []
#             self             = false
#             to_port          = 443
#         },
#     ]
#     tags = {
#       Name = "uat-app-k8s-sg1"
#       Environment = "uat"
#       Terraform = "true"
#     }
#     tags_all    = {}
#     vpc_id      = aws_vpc.uat_infra_1.id
#     timeouts {}
# }


# output additional_security_group_for_k8s {
#   value = aws_security_group.uat_app_k8s_sg1.id
# }


resource "aws_ec2_transit_gateway_vpc_attachment" "attach_firewall_entrypoints_to_tgw" {
  depends_on = [ aws_ram_resource_share_accepter.accept_tgw_from_shared_infra ]
  subnet_ids         = [aws_subnet.uat_firewall1_entrypoint1.id, aws_subnet.uat_firewall1_entrypoint2.id]
  transit_gateway_id = local.internal_tgw_id
  vpc_id             = aws_vpc.uat_infra_1.id
  appliance_mode_support = "enable"
}

output "uat_k8s_vpc_tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.attach_firewall_entrypoints_to_tgw.id
}


variable account_id {}


resource "aws_ram_resource_share" "share_infra_to_uat_application" {
  name                      = local.uat_infra_vpc1_name
  allow_external_principals = false

  tags = {
    Environment = "uat"
    Terraform = "true"
  }
}
