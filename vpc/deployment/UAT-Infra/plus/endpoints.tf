resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.uat_infra_1.id
  service_name = "com.amazonaws.ap-south-1.s3"
  route_table_ids = concat(aws_route_table.uat_app_k8s_private_rt[*].id, aws_route_table.uat_cde_private_rt[*].id, aws_route_table.uat_noncde_private_rt[*].id)
  tags = merge(local.tags,tomap({"Name" = "uat-s3-endpoint"}))
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       =  aws_vpc.uat_infra_1.id
  service_name = "com.amazonaws.ap-south-1.dynamodb"
  route_table_ids = concat(aws_route_table.uat_app_k8s_private_rt[*].id, aws_route_table.uat_cde_private_rt[*].id, aws_route_table.uat_noncde_private_rt[*].id)
  tags = merge(local.tags,tomap({"Name" = "uat-dynamodb-endpoint"}))
}


# locals {
#   ssm_vpcs = [aws_vpc.uat_infra_1, aws_vpc.uat_noncde_db_infra1]
# }
# resource "aws_security_group" "ssm_sg" {
#     count = length(local.ssm_vpcs)
#     description = "Communication between vpc and ssm service"
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
#             cidr_blocks      = local.ssm_vpcs[*].cidr_block
#             description      = "allow ssm port from vpc cidr"
#             from_port        = 443
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "tcp"
#             security_groups  = []
#             self             = false
#             to_port          = 443
#         },
#     ]

#     tags = merge(local.tags,tomap({"Name" = "uat-infra-ssm-sg-${local.ssm_vpcs[count.index].id}"}))
#     vpc_id      = local.ssm_vpcs[count.index].id
#     timeouts {}
# }

# locals {
#     interface_endpoint_services = toset(["ssm", "ec2messages", "ssmmessages", "kms"])
# }

# resource "aws_vpc_endpoint" "interface_endpoint_uat_infra_1" {
#   for_each = local.interface_endpoint_services
#   vpc_id       = aws_vpc.uat_infra_1.id
#   service_name = "com.amazonaws.ap-south-1.${each.key}"
#   vpc_endpoint_type = "Interface"

#   security_group_ids = [
#     aws_security_group.ssm_sg[0].id
#   ]

#   private_dns_enabled = true

#   tags = merge(local.tags,tomap({"Name" = "${each.key}-interface-endpoint-${aws_vpc.uat_infra_1.id}"}))
# }



# resource "aws_vpc_endpoint" "interface_endpoint_uat_noncde_db" {
#   for_each = local.interface_endpoint_services
#   vpc_id       = aws_vpc.uat_noncde_db_infra1.id
#   service_name = "com.amazonaws.ap-south-1.${each.key}"
#   vpc_endpoint_type = "Interface"

#   security_group_ids = [
#     aws_security_group.ssm_sg[1].id
#   ]

#   private_dns_enabled = true

#   tags = merge(local.tags,tomap({"Name" = "${each.key}-interface-endpoint-${aws_vpc.uat_noncde_db_infra1.id}"}))
# }

# locals {
#    spt_subnets = [
#       aws_subnet.uat_noncde_public1,
#       aws_subnet.uat_noncde_public2
#     ]
#     spt_subnets_noncde_db = [
#       aws_subnet.uat_noncde_db1_private1,
#       aws_subnet.uat_noncde_db1_private2
#     ]

#     interace_associated_subnets = local.spt_subnets
# }

# resource "aws_vpc_endpoint_subnet_association" "interface_endpoint_subnet_association_1" {
#   for_each = aws_vpc_endpoint.interface_endpoint_uat_infra_1
#   vpc_endpoint_id = each.value.id
#   subnet_id       = aws_subnet.uat_noncde_public1.id
# }

# resource "aws_vpc_endpoint_subnet_association" "interface_endpoint_subnet_association_2" {
#   for_each = aws_vpc_endpoint.interface_endpoint_uat_infra_1
#   vpc_endpoint_id = each.value.id
#   subnet_id       = aws_subnet.uat_noncde_public2.id
# }


# resource "aws_vpc_endpoint_subnet_association" "interface_endpoint_subnet_association_noncde_db1" {
#   for_each = aws_vpc_endpoint.interface_endpoint_uat_noncde_db
#   vpc_endpoint_id = each.value.id
#   subnet_id       = aws_subnet.uat_noncde_db1_private1.id
# }

# resource "aws_vpc_endpoint_subnet_association" "interface_endpoint_subnet_association_noncde_db2" {
#   for_each = aws_vpc_endpoint.interface_endpoint_uat_noncde_db
#   vpc_endpoint_id = each.value.id
#   subnet_id       = aws_subnet.uat_noncde_db1_private2.id
# }