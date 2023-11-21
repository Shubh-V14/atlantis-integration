data "aws_ami" "eks_default_bottlerocket" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${local.eks_cluster_1.version}-x86_64-*"]
  }
}

module "ebs_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "Customer managed key to encrypt EKS managed node group volumes"

  # Policy
  key_administrators = [
    "arn:aws:iam::${var.account_id}:root"
  ]

  key_service_roles_for_autoscaling = [
    # required for the ASG to manage encrypted volumes for nodes
    "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
    # required for the cluster / persistentvolume-controller to create encrypted PVCs
    module.stage1_eks.cluster_iam_role_arn,
  ]

  # Aliases
  aliases = ["eks/nodegroup1/ebs"]

  tags = local.tags
}

locals {
    # active_nodegroups = []
    active_nodegroups = []
    #Disabling nodegroup management separately in favour of just karpenter
}