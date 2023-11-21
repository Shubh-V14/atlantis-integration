locals {
    prod_noncde_infra_vpc1_name = "prod-noncde-infra1"
    prod_noncde_infra_vpc1_cidr = "10.0.128.0/19"
}

locals {
      tags = {
      Environment = "prod"
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
  prod_application_account_id = lookup(var.account_mapping, "Prod-Application", 0)
  utkarsh_cidrs = [
    "10.172.213.27/32",
    "10.1.1.4/32",
    "10.172.213.30/32"
  ]
  utkarsh_dr_cidrs = [
    "172.16.213.27/32"
  ]
}


locals {
  shared_infra_1_vpc_id = data.terraform_remote_state.shared_infra.outputs.shared_infra_1_id
  internal_tgw_id =  data.terraform_remote_state.shared_infra.outputs.ups_tgw_id
  internal_tgw_rt_id = data.terraform_remote_state.shared_infra.outputs.ups_tgw_rt_id
  shared_infra_tgw_id = data.terraform_remote_state.shared_infra.outputs.ups_tgw_id
  shared_infra_clientvpn_private1_sub_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private1_sub_cidr
  shared_infra_clientvpn_private2_sub_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private2_sub_cidr
}

resource "aws_vpc" "prod_noncde_infra_1" {
  ipv4_ipam_pool_id = "ipam-pool-032220a8f1e82c627"
  cidr_block       = local.prod_noncde_infra_vpc1_cidr
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "prod-noncde-infra-1"
    Environment = "prod"
    Terraform = "true"
  }
}

output "vpc_prod_noncde_infra_1_id" {
  value = aws_vpc.prod_noncde_infra_1.id
}


###VPC Flow logs


# aws_iam_policy.ups_prod_loki_policy:
resource "aws_iam_policy" "flow_log_permissions" {
    description = "ups-flow-log-permissions"
    name        = "ups-flow-log-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOT
    tags        = {}
    tags_all    = {}
}


# aws_iam_role.ups_prod_loki_role:
resource "aws_iam_role" "ups_flow_logs_creator" {
    assume_role_policy    = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
} 
EOT
    description           = "ups-flow-logs-creator"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.flow_log_permissions.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-flow-log-creator"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_flow_log_creator_role_arn" {
    value = aws_iam_role.ups_flow_logs_creator.arn
}


resource "aws_flow_log" "prod_noncde_infra_vpc1_flow_logs" {
  iam_role_arn    = aws_iam_role.ups_flow_logs_creator.arn
  log_destination = aws_cloudwatch_log_group.prod_noncde_infra_vpc1_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id = aws_vpc.prod_noncde_infra_1.id
}

resource "aws_cloudwatch_log_group" "prod_noncde_infra_vpc1_flow_logs" {
  name = "prod-noncde-infra-vpc1-flow-logs"
}



resource "aws_internet_gateway" "prod_noncde_igw1" {
  vpc_id     = aws_vpc.prod_noncde_infra_1.id

  tags = {
    Name = "prod-noncde-igw1"
    Environment = "prod"
    Terraform = "true"
  }
}

##############################################



variable account_id {}
variable account_mapping {
  type = map(string)
}



resource "aws_ram_resource_share" "share_prod_noncde_infra_to_prod_application" {
  name                      = local.prod_noncde_infra_vpc1_name
  allow_external_principals = false

  tags = {
    Environment = "prod"
    Terraform = "true"
  }
}

resource "aws_ram_principal_association" "share_infra_to_prod_application" {
  principal          = local.prod_application_account_id
  resource_share_arn = aws_ram_resource_share.share_prod_noncde_infra_to_prod_application.arn
}



resource "aws_route_table" "igw_ingress_rt" {
vpc_id = aws_vpc.prod_noncde_infra_1.id

dynamic "route" {
    for_each = local.prod_noncde_public_subnets
    content {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }


dynamic "route" {
    for_each = local.firewall_egress_subnets
    content {
      cidr_block = route.value.cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.key]
    }
  }

  tags = merge(local.tags,tomap({"Name" = "prod-noncde-infra-igw-ingress-rt"}))
}