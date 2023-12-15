#EKS Cluster

locals {
    eks_cluster_1 = {
      name = "stage1"
      version = "1.27"
    }
    clientvpn_private1_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private1_sub_cidr
    clientvpn_private2_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private2_sub_cidr
    clientvpn_cidrs = [local.clientvpn_private1_cidr, local.clientvpn_private2_cidr]
    subnet_ids_for_eks_control_plane_subnets = data.terraform_remote_state.stage_infra.outputs.subnet_ids_for_eks_control_plane_subnets
    subnet_ids_for_nodegroup1 = data.terraform_remote_state.stage_infra.outputs.subnet_ids_for_nodegroup1
    subnet_cidrs_for_nodegroup1 = data.terraform_remote_state.stage_infra.outputs.subnet_cidrs_for_nodegroup1
    subnet_ids_for_public_subnets = data.terraform_remote_state.stage_infra.outputs.subnet_ids_for_public_subnets
    subnet_ids_for_db_infra1_subnets = data.terraform_remote_state.stage_infra.outputs.subnet_ids_for_db_infra1
    infra1_vpc_id = data.terraform_remote_state.stage_infra.outputs.infra1_vpc_id
    db_infra1_vpc_id = data.terraform_remote_state.stage_infra.outputs.db_infra1_vpc_id
    infra1_vpc_cidr_block = data.terraform_remote_state.stage_infra.outputs.infra1_vpc_cidr_block
}

module "stage1_eks" {
  source = "../../../modules/eks/cluster/v1"
  name = local.eks_cluster_1.name
  variant = local.variant
  tags = local.tags
  control_plane_subnet_ids = local.subnet_ids_for_eks_control_plane_subnets
  allowed_cidrs = local.clientvpn_cidrs
  account_id = var.account_id
  cloudwatch_log_group_retention_in_days = 7
  vpc_id = local.infra1_vpc_id
  vpc_cidr_block = local.infra1_vpc_cidr_block
}

data "aws_iam_role" "ng" {
    count = length(local.active_nodegroups)
    name = "${local.active_nodegroups[count.index]}-node-group"
    depends_on = [ module.spot_mix_ng ]
}

locals {
   node_iam_role_arns_non_windows = data.aws_iam_role.ng[*].arn
}

data "aws_eks_cluster_auth" "main" {
  name = module.stage1_eks.cluster_name
}

provider "kubernetes" {
    alias = "eks"
    host                   = module.stage1_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.stage1_eks.cluster_certificate_authority_data)
    token = data.aws_eks_cluster_auth.main.token
}

resource "aws_ec2_tag" "karpenter_discovery" {
  resource_id = local.subnet_ids_for_nodegroup1[0]
  key         = "karpenter.sh/discovery"
  value       = module.stage1_eks.cluster_name
}

resource "aws_ec2_tag" "internal_elb" {
  resource_id = local.subnet_ids_for_nodegroup1[0]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "external_elb" {
  resource_id = local.subnet_ids_for_public_subnets[0]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}


locals {
  additional_fargate_profiles = [
    {"name": "kyverno", "namespace": "kyverno"}
    ]
}

module "additional_fargate_profiles" {
  count = length(local.additional_fargate_profiles)
  source = "terraform-aws-modules/eks/aws//modules/fargate-profile"

  name         = local.additional_fargate_profiles[count.index]["name"]
  cluster_name = module.stage1_eks.cluster_name

  subnet_ids = [local.subnet_ids_for_nodegroup1[0]]
  selectors = [{
    namespace = "${local.additional_fargate_profiles[count.index]["namespace"]}"
  }]

  tags = local.tags
}

module "fargate_profile" {
  source = "terraform-aws-modules/eks/aws//modules/fargate-profile"

  name         = "karpenter"
  cluster_name = module.stage1_eks.cluster_name

  subnet_ids = [local.subnet_ids_for_nodegroup1[0]]
  selectors = [{
    namespace = "karpenter"
  }]

  tags = local.tags
}



locals {
  karpenter_auth_role = {
      rolearn  = module.karpenter.role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    }
  dev_auth_role = {
    rolearn = "arn:aws:iam::044412563252:role/stage-k8s-dev-3"
      groups = [
        "stage-k8s-dev-3"
      ]
  }
}
 

module "aws_auth" {
    source = "../../../modules/eks/aws_auth/v1"
    node_iam_role_arns_non_windows = local.node_iam_role_arns_non_windows
    depends_on = [ module.stage1_eks, module.karpenter]
    fargate_profile_pod_execution_role_arns = concat([module.fargate_profile.fargate_profile_pod_execution_role_arn], module.additional_fargate_profiles[*].fargate_profile_pod_execution_role_arn)
    aws_auth_roles = [local.karpenter_auth_role]
    aws_auth_roles_groups = [local.dev_auth_role]
    providers = {
        kubernetes = kubernetes.eks
    }
}

resource "aws_security_group_rule" "allow_from_control_plan_to_nodes" {
  type              = "ingress"
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  source_security_group_id = module.stage1_eks.cluster_primary_security_group_id
  security_group_id = module.stage1_eks.node_security_group_id
  description = "From Control Plane to Node Groups"
}

