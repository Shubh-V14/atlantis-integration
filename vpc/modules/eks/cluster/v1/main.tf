##stuck at kms_key_administrators
#pass current account id for key admin

variable vpc_id {}
variable vpc_cidr_block {}

variable tags {
    type = map(string)
}

variable name {
    type = string
}

variable variant {}

variable control_plane_subnet_ids {
    type = list(string)
}

variable cloudwatch_log_group_retention_in_days {
    type = string
}

variable allowed_cidrs {
    type = list(string)
}

variable cluster_enabled_log_types {
  type = list(string)
  default =  ["api", "audit"]
}

variable account_id {}


data "aws_eks_cluster_auth" "main" {
  name = local.name
}


provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.main.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}


data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name            = var.name
  cluster_version = "1.27"
  region          = "ap-south-1"

  vpc_cidr = var.vpc_cidr_block
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(var.tags, {"eks_cluster_name":"${var.name}"})
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_ip_family = "ipv6"
  create_cni_ipv6_iam_policy = true

  cluster_endpoint_public_access = false
  cluster_endpoint_private_access = true
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cluster_enabled_log_types = var.cluster_enabled_log_types
  cluster_encryption_config = {
    "resources": [
      "secrets"
    ]
  }
  cluster_addons = {
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  #todo Add coredns to fargate

  vpc_id                   = var.vpc_id
  control_plane_subnet_ids = var.control_plane_subnet_ids
  cluster_additional_security_group_ids = [aws_security_group.main.id]
  kms_key_administrators = ["arn:aws:iam::${var.account_id}:root"]
  tags = local.tags
  node_security_group_tags = merge(local.tags, {"karpenter.sh/discovery" = local.name})

  # Self managed node groups will not automatically create the aws-auth configmap so we need to
  create_aws_auth_configmap = true
  manage_aws_auth_configmap = false

  cluster_security_group_use_name_prefix = true
  

}

output "cluster_arn" {
  value = module.eks.cluster_arn
}
output "cluster_iam_role_arn" {
  value = module.eks.cluster_iam_role_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_primary_security_group_id" {
  value = module.eks.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider
}
