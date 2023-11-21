locals {
  variant = "stage"
  tags = {
    Environment = local.variant
    Terraform   = "true"
  }
  infra1_vpc = {
    ipam_pool_id = "ipam-pool-0404014bd7e58ad3d"
    name         = "infra1"
    cidr         = "172.16.2.0/24"
    az_prefix    = "aps1"
    subnets = {
      #Subnets for EKS control plane
      eks_control_plane_subnets = {
        cidr = ["172.16.2.0/28", "172.16.2.16/28"]
        name = "eks-control-plane"
        ipv6_cidr = ["2406:da1a:b7a:6d00::/64", "2406:da1a:b7a:6d01::/64"]
      }

      #Subnets for tgw entrypoint
      tgw_entrypoint_subnets = {
        cidr = ["172.16.2.32/28", "172.16.2.48/28"]
        name = "tgw-entrypoint"
        ipv6_cidr = ["2406:da1a:b7a:6d02::/64", "2406:da1a:b7a:6d03::/64"]
      }
      #Subnets for Node Group in EKS
      nodegroup1_subnets = {
        cidr = ["172.16.2.64/26", "172.16.2.128/26"]
        name = "nodegroup1"
        ipv6_cidr = ["2406:da1a:b7a:6d04::/64", "2406:da1a:b7a:6d05::/64"]
      }

      public_subnets = {
        cidr = ["172.16.2.192/28", "172.16.2.208/28"]
        name = "public"
        ipv6_cidr = ["2406:da1a:b7a:6d06::/64", "2406:da1a:b7a:6d07::/64"]
      }
    }
  }
  clientvpn_private1_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private1_sub_cidr
  clientvpn_private2_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private2_sub_cidr
  clientvpn_cidrs         = [local.clientvpn_private1_cidr, local.clientvpn_private2_cidr]
  tgw_id                  = data.terraform_remote_state.shared_infra.outputs.ups_tgw_id
}


#Get State from Share-Infra Account
data "terraform_remote_state" "shared_infra" {
  backend = "s3"

  config = {
    bucket       = "ups-infra-state"
    region       = "ap-south-1"
    key          = "vpc/deployment/Shared-Infra/plus/terraform.tfstate"
    role_arn     = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

variable account_id {}


#Create main VPC for EKS Cluster
module "vpc1" {
  source            = "../../../modules/vpc/v1"
  name              = local.infra1_vpc.name
  variant           = local.variant
  ipv4_ipam_pool_id = local.infra1_vpc.ipam_pool_id
  cidr_block        = local.infra1_vpc.cidr
  enable_flow_log = true
  create_flow_log_cloudwatch_iam_role = true
  create_flow_log_cloudwatch_log_group = true
}

output "infra1_vpc_id" {
  value = module.vpc1.vpc_id
}

output "infra1_vpc_cidr_block" {
  value = module.vpc1.vpc_cidr_block
}

#Create Internet Gateway and NAT Gateway
#========================================

resource "aws_internet_gateway" "main" {
  vpc_id     = module.vpc1.vpc_id

  tags = local.tags
}

resource "aws_eip" "ngw" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw_for_primary_subnet" {
  allocation_id = aws_eip.ngw.allocation_id
  subnet_id     = module.public_subnets.subnet_ids[0]

  tags = local.tags

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}


#When enabling egress only gateway, fargate provisioning was not working
#guess it's working with either egress only route or nat route but not when both are enabled
#fyi, fargate seems to support dual stack
resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = module.vpc1.vpc_id

  tags = local.tags
}


#========================================

#Create Public Subnets

#Create Private subnets for hosting eks control plane
module "public_subnets" {
  source    = "../../../modules/subnet_set/k8s_cluster/v1"
  cidrs     = local.infra1_vpc.subnets.public_subnets.cidr
  vpc_id    = module.vpc1.vpc_id
  az_prefix = local.infra1_vpc.az_prefix
  name      = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.public_subnets.name}-subnet"
  variant   = local.variant
  ipv6_cidr_block = local.infra1_vpc.subnets.public_subnets.ipv6_cidr
}

output "subnet_ids_for_public_subnets" {
  value = module.public_subnets.subnet_ids
}

output "subnet_cidrs_for_public_subnets" {
  value = module.subnets_for_nodegroup1.subnet_cidrs
}

module "rt_for_public_subnets" {
  source     = "../../../modules/rt_set/v1"
  subnet_ids = module.public_subnets.subnet_ids
  subnet_count = length(local.infra1_vpc.subnets.public_subnets.cidr)
  vpc_id     = module.vpc1.vpc_id
  variant    = local.variant
  name       = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.public_subnets.name}-rt"
  igw_routes = [{ cidr_block : "0.0.0.0/0", igw_id: aws_internet_gateway.main.id}]
  depends_on = [module.public_subnets]
}



#Create Private subnets for hosting eks control plane
module "subnets_for_eks_control_plane" {
  source    = "../../../modules/subnet_set/k8s_cluster/v1"
  cidrs     = local.infra1_vpc.subnets.eks_control_plane_subnets.cidr
  vpc_id    = module.vpc1.vpc_id
  az_prefix = local.infra1_vpc.az_prefix
  name      = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.eks_control_plane_subnets.name}-subnet"
  variant   = local.variant
  ipv6_cidr_block = local.infra1_vpc.subnets.eks_control_plane_subnets.ipv6_cidr
}

output "subnet_ids_for_eks_control_plane_subnets" {
  value = module.subnets_for_eks_control_plane.subnet_ids
}

module "rt_for_control_plane_subnets" {
  source     = "../../../modules/rt_set/v1"
  subnet_ids = module.subnets_for_eks_control_plane.subnet_ids
  subnet_count = length(local.infra1_vpc.subnets.eks_control_plane_subnets.cidr)
  vpc_id     = module.vpc1.vpc_id
  variant    = local.variant
  name       = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.eks_control_plane_subnets.name}-rt"
  tg_routes  = [{ cidr_block : local.clientvpn_private1_cidr, tgw_id : local.tgw_id }, { cidr_block : local.clientvpn_private2_cidr, tgw_id : local.tgw_id }]
  depends_on = [module.subnets_for_eks_control_plane]
}


#Create Private subnets for tgw entrypoint
module "subnets_for_tgw_entrypoint" {
  source    = "../../../modules/subnet_set/k8s_cluster/v1"
  cidrs     = local.infra1_vpc.subnets.tgw_entrypoint_subnets.cidr
  vpc_id    = module.vpc1.vpc_id
  az_prefix = local.infra1_vpc.az_prefix
  name      = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.tgw_entrypoint_subnets.name}-subnet"
  variant   = local.variant
  ipv6_cidr_block = local.infra1_vpc.subnets.tgw_entrypoint_subnets.ipv6_cidr
}

output "subnet_ids_for_tgw_entrypoint" {
  value = module.subnets_for_tgw_entrypoint.subnet_ids
}

module "rt_for_tgw_entrypoint_subnets" {
  source     = "../../../modules/rt_set/v1"
  subnet_ids = module.subnets_for_tgw_entrypoint.subnet_ids
  subnet_count = length(local.infra1_vpc.subnets.tgw_entrypoint_subnets.cidr)
  vpc_id     = module.vpc1.vpc_id
  variant    = local.variant
  name       = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.tgw_entrypoint_subnets.name}-rt"
  # tg_routes  = [{ cidr_block : local.clientvpn_private1_cidr, tgw_id : local.tgw_id }]
  depends_on = [module.subnets_for_tgw_entrypoint ]
}

#Create Private subnets for hosting nodegroups in EKS
module "subnets_for_nodegroup1" {
  source    = "../../../modules/subnet_set/k8s_cluster/v1"
  cidrs     = local.infra1_vpc.subnets.nodegroup1_subnets.cidr
  vpc_id    = module.vpc1.vpc_id
  az_prefix = local.infra1_vpc.az_prefix
  name      = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.nodegroup1_subnets.name}-subnet"
  variant   = local.variant
  ipv6_cidr_block = local.infra1_vpc.subnets.nodegroup1_subnets.ipv6_cidr
}

output "subnet_ids_for_nodegroup1" {
  value = module.subnets_for_nodegroup1.subnet_ids
}

output "subnet_cidrs_for_nodegroup1" {
  value = module.subnets_for_nodegroup1.subnet_cidrs
}

locals {
  infra1_db_infra1_pc_routes = [for cidr in module.subnets_for_db_infra1.subnet_cidrs: {
    "cidr_block": cidr, 
    "peering_connection_id": aws_vpc_peering_connection.infra1_db_infra1_pc.id
  }]
}


locals {
  utkarsh_cidrs = ["10.172.223.113/32", "10.172.223.15/32", "10.184.14.40/32"]
  utkarsh_tgw_routes = [for cidr in local.utkarsh_cidrs: {"cidr_block": cidr, "tgw_id": local.tgw_id}]
}
module "rt_for_nodegroup_subnets" {
  source     = "../../../modules/rt_set/v1"
  subnet_ids = module.subnets_for_nodegroup1.subnet_ids
  subnet_count = length(local.infra1_vpc.subnets.nodegroup1_subnets.cidr)
  vpc_id     = module.vpc1.vpc_id
  variant    = local.variant
  name       = "${local.infra1_vpc.name}-${local.infra1_vpc.subnets.nodegroup1_subnets.name}-rt"
  tg_routes  = concat([{ cidr_block : local.clientvpn_private1_cidr, tgw_id : local.tgw_id }, { cidr_block : local.clientvpn_private2_cidr, tgw_id : local.tgw_id }], local.utkarsh_tgw_routes)
  ngw_routes = [{cidr_block : "0.0.0.0/0", ngw_id: aws_nat_gateway.ngw_for_primary_subnet.id}]
  egw_routes = [{cidr_block: "::/0", egw_id: aws_egress_only_internet_gateway.main.id}]
  peering_routes = local.infra1_db_infra1_pc_routes
  depends_on = [module.subnets_for_nodegroup1 ]
}


#Attaching tgw entrypoint subnets 
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  subnet_ids             = module.subnets_for_tgw_entrypoint.subnet_ids
  transit_gateway_id     = local.tgw_id
  vpc_id                 = module.vpc1.vpc_id
  appliance_mode_support = "enable"
  depends_on             = [aws_ram_resource_share_accepter.accept_tgw_from_shared_infra]
}




#Some bug in aws/tf side which cause this resource to always fail
# some ref https://github.com/hashicorp/terraform-provider-aws/issues/13494 but issue remains even after awaiting for 10min and having latest aws provider 
# Just untaint the resource after failure and tf will be good to go
# Update - Removing this from tf code as this cause huge delays when reconciling , takes time for no identified reason
resource "aws_ram_resource_share_accepter" "accept_tgw_from_shared_infra" {
  share_arn = data.terraform_remote_state.shared_infra.outputs.tgw_external_share_arns["${var.account_id}"]["resource_share_arn"]
}

#Share Stage-Infra VPC to Stage-Application


resource "aws_ram_resource_share" "main" {
  name = "main"
  tags = local.tags
}

variable "account_mapping" {
  type = map(string)
}
resource "aws_ram_principal_association" "main" {
  principal          = lookup(var.account_mapping, "Upswing-Stage-Application", 0)
  resource_share_arn = aws_ram_resource_share.main.arn
}

locals {
  subnets_to_share_to_application_account = concat(module.subnets_for_eks_control_plane.subnet_arns, module.subnets_for_nodegroup1.subnet_arns, module.public_subnets.subnet_arns)
}
#Share subnets to Stage Application
resource "aws_ram_resource_association" "subnets" {
  count              = length(local.infra1_vpc.subnets.nodegroup1_subnets.cidr) + length(local.infra1_vpc.subnets.eks_control_plane_subnets.cidr) + length(local.infra1_vpc.subnets.public_subnets.cidr)
  resource_arn       = local.subnets_to_share_to_application_account[count.index]
  resource_share_arn = aws_ram_principal_association.main.resource_share_arn
}
