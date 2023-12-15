variable ipv4_ipam_pool_id {
    type = string
}

variable cidr_block {
    type = string
}

variable variant {
    type = string
}
    
variable name {
    type = string
}

variable enable_flow_log {
  default = false
}

variable create_flow_log_cloudwatch_iam_role {
  default = false
}

variable create_flow_log_cloudwatch_log_group {
  default = false
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr  = var.cidr_block
  ipv4_ipam_pool_id = var.ipv4_ipam_pool_id

  enable_nat_gateway = false
  enable_vpn_gateway = false
  default_vpc_enable_dns_hostnames = true
  enable_flow_log = var.enable_flow_log
  create_flow_log_cloudwatch_log_group = var.create_flow_log_cloudwatch_log_group
  create_flow_log_cloudwatch_iam_role = var.create_flow_log_cloudwatch_iam_role
  default_vpc_enable_dns_support = true
  instance_tenancy = "default"
  enable_ipv6 = true
  public_subnet_assign_ipv6_address_on_creation = true


  tags = {
    Name = "${var.variant}-${var.name}"
    Environment = var.variant
    Terraform = "true"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "name" {
  value = module.vpc.name
}