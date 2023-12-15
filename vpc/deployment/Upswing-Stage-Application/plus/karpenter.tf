
variable account_mapping {
  type = map(string)
}

provider "helm" {
  kubernetes {
    host                   = module.stage1_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.stage1_eks.cluster_certificate_authority_data)
    token = data.aws_eks_cluster_auth.main.token
  }
}


provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.stage1_eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.stage1_eks.cluster_certificate_authority_data)
  load_config_file       = false
  token = data.aws_eks_cluster_auth.main.token
}

################################################################################
# Karpenter
################################################################################

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name           = module.stage1_eks.cluster_name
  irsa_oidc_provider_arn = module.stage1_eks.oidc_provider_arn
  iam_role_use_name_prefix = false
  irsa_namespace_service_accounts = ["karpenter:karpenter"]
  irsa_subnet_account_id = lookup(var.account_mapping, "Upswing-Stage-Infra", 0)

  iam_role_additional_policies = [
     "arn:aws:iam::${var.account_id}:policy/AmazonEKS_CNI_IPv6_Policy",
     "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = local.tags
}


provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

resource "helm_release" "karpenter" {
  # lifecycle {
  #   ignore_changes = [repository_password]
  # }
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.30.0"

  set {
    name  = "settings.aws.clusterName"
    value = module.stage1_eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.stage1_eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }

}


resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.stage1_eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.stage1_eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.stage1_eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}
