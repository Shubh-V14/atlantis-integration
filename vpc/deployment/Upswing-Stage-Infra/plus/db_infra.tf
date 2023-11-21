locals {
  db_infra1_vpc = {
    ipam_pool_id = "ipam-pool-0404014bd7e58ad3d"
    name         = "db-infra1"
    cidr         = "172.16.3.0/26"
    az_prefix    = "aps1"
    subnets = {
      #Subnets for EKS control plane
      db1_subnets = {
        cidr = ["172.16.3.0/28", "172.16.3.16/28"]
        name = "db1-subnets"
      }
    }
  }
}

#Create main VPC for EKS Cluster
module "db_infra1_vpc" {
  source            = "../../../modules/vpc/v1"
  name              = local.db_infra1_vpc.name
  variant           = local.variant
  ipv4_ipam_pool_id = local.db_infra1_vpc.ipam_pool_id
  cidr_block        = local.db_infra1_vpc.cidr
  enable_flow_log = false
  create_flow_log_cloudwatch_iam_role = false
  create_flow_log_cloudwatch_log_group = false
}

output "db_infra1_vpc_id" {
  value = module.db_infra1_vpc.vpc_id
}

output "db_infra1_vpc_cidr_block" {
  value = module.db_infra1_vpc.vpc_cidr_block
}

resource "aws_vpc_peering_connection" "infra1_db_infra1_pc" {
  peer_owner_id = var.account_id
  peer_vpc_id   = module.vpc1.vpc_id
  vpc_id        = module.db_infra1_vpc.vpc_id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between ${module.vpc1.name} vpc and ${module.db_infra1_vpc.name} vpc"
  }
}

output "infra1_db_infra1_pc_id" {
  value = aws_vpc_peering_connection.infra1_db_infra1_pc.id
}

#Create Private subnets for hosting nodegroups in EKS
module "subnets_for_db_infra1" {
  source    = "../../../modules/subnet_set/k8s_cluster/v1"
  cidrs     = local.db_infra1_vpc.subnets.db1_subnets.cidr
  vpc_id    = module.db_infra1_vpc.vpc_id
  az_prefix = local.db_infra1_vpc.az_prefix
  name      = "${local.db_infra1_vpc.name}-${local.db_infra1_vpc.subnets.db1_subnets.name}-subnet"
  variant   = local.variant
}

output "subnet_ids_for_db_infra1" {
  value = module.subnets_for_db_infra1.subnet_ids
}

locals {
  db_infra1_infra1_pc_routes = [for cidr in module.subnets_for_nodegroup1.subnet_cidrs: {
    "cidr_block": cidr, 
    "peering_connection_id": aws_vpc_peering_connection.infra1_db_infra1_pc.id
  }]
}


module "rt_for_db_infra1_subnets" {
  source     = "../../../modules/rt_set/v1"
  subnet_ids = module.subnets_for_db_infra1.subnet_ids
  subnet_count = length(local.db_infra1_vpc.subnets.db1_subnets.cidr)
  vpc_id     = module.db_infra1_vpc.vpc_id
  variant    = local.variant
  name       = "${local.db_infra1_vpc.name}-${local.db_infra1_vpc.subnets.db1_subnets.name}-rt"
  peering_routes = local.db_infra1_infra1_pc_routes
  depends_on = [module.subnets_for_nodegroup1 ]
}

locals {
  db_infra1_subnets_to_share_to_application_account = concat(module.subnets_for_db_infra1.subnet_arns)
}
#Share subnets to Stage Application
resource "aws_ram_resource_association" "db_infra1_subnets" {
  count              = length(local.db_infra1_vpc.subnets.db1_subnets.cidr)
  resource_arn       = local.db_infra1_subnets_to_share_to_application_account[count.index]
  resource_share_arn = aws_ram_principal_association.main.resource_share_arn
}
