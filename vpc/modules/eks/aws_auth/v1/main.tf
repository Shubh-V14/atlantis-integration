  variable  node_iam_role_arns_non_windows {
    type = list(string)
    default = []
  }

  variable aws_auth_users {
    type = list(string)
    default = []
  }

  variable aws_auth_accounts {
    type = list(string)
    default = []
  }

  variable aws_auth_roles {
   type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
    default = []
  }

  variable aws_auth_roles_groups {
   type = list(object({
    rolearn  = string
    groups   = list(string)
  }))
    default = []
  }

  variable fargate_profile_pod_execution_role_arns {
    type = list(string) 
  }


  locals {
    aws_auth_configmap_data = {
      mapRoles = yamlencode(concat(
        [for role_arn in var.node_iam_role_arns_non_windows : {
          rolearn  = role_arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups = [
            "system:bootstrappers",
            "system:nodes",
          ]
          }
        ],
        # Fargate profile
        [for role_arn in var.fargate_profile_pod_execution_role_arns : {
          rolearn  = role_arn
          username = "system:node:{{SessionName}}"
          groups = [
            "system:bootstrappers",
            "system:nodes",
            "system:node-proxier",
          ]
          }
        ],
        var.aws_auth_roles,
        var.aws_auth_roles_groups

      ))
      mapUsers    = yamlencode(var.aws_auth_users)
      mapAccounts = yamlencode(var.aws_auth_accounts)
    }
  }



  resource "kubernetes_config_map_v1_data" "aws_auth" {
    force = true

    metadata {
      name      = "aws-auth"
      namespace = "kube-system"
    }

    data = local.aws_auth_configmap_data

}