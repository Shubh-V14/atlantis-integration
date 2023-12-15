
resource "aws_vpn_gateway" "hitachi1_vpn" {
  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "hitachi1-vpn-gateway2"}))
  amazon_side_asn = "64512"
}

resource "aws_vpn_gateway_attachment" "hitachi1_vpn_attachment" {
  vpc_id         = aws_vpc.shared_infra_3.id
  vpn_gateway_id = aws_vpn_gateway.hitachi1_vpn.id

}

resource "aws_vpc" "shared_infra_3" {
  ipv4_ipam_pool_id = "ipam-pool-04cf9adbc110ccb77"
  cidr_block       = "10.5.65.128/26"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-3"}))
}



resource "aws_subnet" "vpn2_private1" {
  vpc_id     = aws_vpc.shared_infra_3.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.5.65.128/28"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-private1"}))
}

resource "aws_subnet" "vpn2_private2" {
  vpc_id     = aws_vpc.shared_infra_3.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.5.65.144/28"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-private2"}))
}


resource "aws_subnet" "vpn2_private_entry_1" {
  vpc_id     = aws_vpc.shared_infra_3.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.5.65.160/28"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-private-entry-1"}))
}

resource "aws_subnet" "vpn2_private_entry_2" {
  vpc_id     = aws_vpc.shared_infra_3.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.5.65.176/28"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-private-entry-2"}))
}



locals {
  vpn2_private_subnets = [aws_subnet.vpn2_private1, aws_subnet.vpn2_private2]
  vpn2_private_entry_subnets = [aws_subnet.vpn2_private_entry_1, aws_subnet.vpn2_private_entry_2]
}

resource "aws_nat_gateway" "vpn2_nat" {
  count = length(local.vpn2_private_subnets)
  subnet_id     = local.vpn2_private_subnets[count.index].id
  connectivity_type = "private"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-nat-${count.index}"}))

}

resource "aws_route_table" "vpn2_private_entry_rt" {
  count = length(local.vpn2_private_subnets)
  vpc_id     = aws_vpc.shared_infra_3.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vpn2_nat[count.index].id
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-private-entry-rt-${count.index}"}))
}

resource "aws_route_table_association" "vpn2_private_entry_rt_association1" {
  count = length(local.vpn2_private_entry_subnets)
  subnet_id      = local.vpn2_private_entry_subnets[count.index].id
  route_table_id = aws_route_table.vpn2_private_entry_rt[count.index].id
}

resource "aws_route_table" "vpn2_private_rt" {
  count = length(local.vpn2_private_subnets)
  vpc_id     = aws_vpc.shared_infra_3.id

  # route {
  #   cidr_block = "0.0.0.0/0"
  #   gateway_id = aws_vpn_gateway.utk-vpn.id
  # }

  dynamic "route" {
      for_each = [local.stage_infra_app_k8s_private1_cidr, local.stage_infra_app_k8s_private2_cidr]
      content  {
          cidr_block = route.value
          transit_gateway_id = module.tgw.ec2_transit_gateway_id
      }
  }

    dynamic "route" {
      for_each = [local.uat_infra_app_k8s_private1_cidr, local.uat_infra_app_k8s_private2_cidr, local.uat_infra_noncde_k8s_private1_cidr, local.uat_infra_noncde_k8s_private2_cidr, local.uat_infra_cde_k8s_private1_cidr, local.uat_infra_cde_k8s_private2_cidr]
      content  {
          cidr_block = route.value
          transit_gateway_id = module.tgw.ec2_transit_gateway_id
      }
    }

    dynamic "route" {
      for_each = [local.prod_k8s_cluster_private2_cidr, local.prod_k8s_cluster_private2_cidr]
      content  {
          cidr_block = route.value
          transit_gateway_id = module.tgw.ec2_transit_gateway_id
      }
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "vpn2-private-rt-${count.index}"}))
}

resource "aws_route_table_association" "vpn2_private_rt_association1" {
  count = length(local.vpn2_private_subnets)
  subnet_id      = local.vpn2_private_subnets[count.index].id
  route_table_id = aws_route_table.vpn2_private_rt[count.index].id
}

resource "aws_vpn_gateway_route_propagation" "propagate_hitachi" {
  count = length(local.vpn2_private_subnets)
  vpn_gateway_id = aws_vpn_gateway.hitachi1_vpn.id
  route_table_id = aws_route_table.vpn2_private_rt[count.index].id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attach_vpn2_entry_subnets_to_tgw" {
  subnet_ids         = [aws_subnet.vpn2_private_entry_1.id, aws_subnet.vpn2_private_entry_2.id]
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = aws_vpc.shared_infra_3.id
  appliance_mode_support = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

}


resource "aws_ec2_transit_gateway_route_table_association" "assocaite_vpn2_entry_subnets_to_tg2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attach_vpn2_entry_subnets_to_tgw.id
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "propogate_vpn2_entry_subnets_to_tg2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.attach_vpn2_entry_subnets_to_tgw.id
  transit_gateway_route_table_id = module.tgw.ec2_transit_gateway_route_table_id
}


# # aws_iam_policy.ups_uat_loki_policy:
# resource "aws_iam_policy" "flow_log_permissions" {
#     description = "ups-flow-log-permissions"
#     name        = "ups-flow-log-permissions"
#     policy      = <<EOT
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "logs:CreateLogGroup",
#                 "logs:CreateLogStream",
#                 "logs:PutLogEvents",
#                 "logs:DescribeLogGroups",
#                 "logs:DescribeLogStreams"
#             ],
#             "Resource": "*"
#         }
#     ]
# }
# EOT
#     tags        = {}
#     tags_all    = {}
# }


# # aws_iam_role.ups_uat_loki_role:
# resource "aws_iam_role" "ups_flow_logs_creator" {
#     assume_role_policy    = <<EOT
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "vpc-flow-logs.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# } 
# EOT
#     description           = "ups-flow-logs-creator"
#     force_detach_policies = false

#     managed_policy_arns   = [
#         "${aws_iam_policy.flow_log_permissions.arn}"
#     ]
#     max_session_duration  = 3600
#     name                  = "ups-flow-log-creator"
#     path                  = "/"
#     tags                  = {}
#     tags_all              = {}

# }

# output "ups_flow_log_creator_role_arn" {
#     value = aws_iam_role.ups_flow_logs_creator.arn
# }


# resource "aws_flow_log" "vpn_private_flow_logs" {
#   count = length(local.vpn2_private_subnets)
#   iam_role_arn    = aws_iam_role.ups_flow_logs_creator.arn
#   log_destination = aws_cloudwatch_log_group.vpn_private_flow_logs.arn
#   traffic_type    = "ALL"
#   subnet_id = local.vpn2_private_subnets[count.index].id
# }

# resource "aws_cloudwatch_log_group" "vpn_private_flow_logs" {
#   name = "vpn-private-flow-logs"
# }



# resource "aws_flow_log" "vpn_private_entry_flow_logs" {
#   count = length(local.vpn2_private_entry_subnets)
#   iam_role_arn    = aws_iam_role.ups_flow_logs_creator.arn
#   log_destination = aws_cloudwatch_log_group.vpn_private_entry_flow_logs.arn
#   traffic_type    = "ALL"
#   subnet_id = local.vpn2_private_entry_subnets[count.index].id
# }

# resource "aws_cloudwatch_log_group" "vpn_private_entry_flow_logs" {
#   name = "vpn-private-entry-flow-logs"
# }

