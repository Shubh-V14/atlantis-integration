locals {
  name = "primary-v1"  
}

module "spot_mix_ng" {
  count = contains(local.active_nodegroups, local.name) ? 1: 0
  source = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"

  name                = local.name
  cluster_name        = local.eks_cluster_1.name
  cluster_version     = local.eks_cluster_1.version
  cluster_endpoint    = module.stage1_eks.cluster_endpoint
  cluster_auth_base64 = module.stage1_eks.cluster_certificate_authority_data

  subnet_ids = [local.subnet_ids_for_nodegroup1[0]] #For Stage, only creating Infra in 0th Subnet to avoid inter az cost

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  vpc_security_group_ids = [
    module.stage1_eks.cluster_primary_security_group_id,
    module.stage1_eks.cluster_security_group_id,
  ]

  iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      AmazonEKS_CNI_IPv6_Policy = "arn:aws:iam::${var.account_id}:policy/AmazonEKS_CNI_IPv6_Policy"
  }

  min_size     = 1
  max_size     = 2
  desired_size = 1

  platform = "bottlerocket"
  ami_id        = data.aws_ami.eks_default_bottlerocket.id
  launch_template_name   = local.name
  use_mixed_instances_policy = true
  mixed_instances_policy = {
    instances_distribution = {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "price-capacity-optimized"
    }
    override = [
      {
        instance_type     = "t3.small"
        weighted_capacity = "3"
      },
      {
        instance_type     = "t3.medium"
        weighted_capacity = "2"
      },
      {
        instance_type     = "t3.large"
        weighted_capacity = "1"
      },
      {
        instance_type     = "t3a.medium"
        weighted_capacity = "1"
      }
    ]
  }
  #update volume type

  bootstrap_extra_args = <<-EOT
    # The admin host container provides SSH access and runs with "superpowers".
    # It is disabled by default, but can be disabled explicitly.
    [settings.host-containers.admin]
    enabled = false

    # The control host container provides out-of-band access via SSM.
    # It is enabled by default, and can be disabled if you do not expect to use SSM.
    # This could leave you with no way to access the API and change settings on an existing node!
    [settings.host-containers.control]
    enabled = true

    # extra args added
    [settings.kernel]
    lockdown = "integrity"
    
    [settings.kernel.modules.udf]
    allowed = false

    [settings.kernel.modules.sctp]
    allowed = false

    [settings.kernel.sysctl]
    # 3.1.1
    "net.ipv4.conf.all.send_redirects" = "0"
    "net.ipv4.conf.default.send_redirects" = "0"
    
    # 3.2.2
    "net.ipv4.conf.all.accept_redirects" = "0"
    "net.ipv4.conf.default.accept_redirects" = "0"
    "net.ipv6.conf.all.accept_redirects" = "0"
    "net.ipv6.conf.default.accept_redirects" = "0"
    
    # 3.2.3
    "net.ipv4.conf.all.secure_redirects" = "0"
    "net.ipv4.conf.default.secure_redirects" = "0"
    
    # 3.2.4
    "net.ipv4.conf.all.log_martians" = "1"
    "net.ipv4.conf.default.log_martians" = "1"

    [settings.kubernetes.node-labels]
    lifecycle = "spot"
    workloadAffinity = "mix"
    workloadType = "continous"

    [settings.kubernetes]
    "ip-family" = "ipv6"
    "service-ipv6-cidr" = "fd2b:2fa9:d746::/108"

    [settings.bootstrap-containers.cis-bootstrap]
    source = "776633114724.dkr.ecr.ap-south-1.amazonaws.com/bottlerocket-bootstrap:main-bottlerocket-bootstrap-105"
    mode = "always"
  EOT


  tags = local.tags
  iam_role_tags = {"role": "eks_nodegroup"}

  #because we want to fetch all nodegroup iam role later and add to aws-auth configmap
  #only way to fetch is using name and thus we need a fixed name
  iam_role_use_name_prefix = false
  use_name_prefix = false
  launch_template_use_name_prefix = false
  
}