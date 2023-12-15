locals {
  helm_charts = [ "backend"]
  helm_charts_2 = [ "argocd","aws-load-balancer-controller","prometheus-blackbox-exporter","calico","cert-manager","cluster-autoscaler","discourse","drone","drone-runner-kube","ebs-csi-driver","efs-csi-driver","keycloak","kiali-server","kyverno","loki-distributed","metrics-server","pulsar","prometheus","promtail","sonarqube","teleport","vault","eventrouter", "kube-prometheus-stack", "mimir-distributed", "keda","aws-ebs-csi-driver", "argo-cd", "teleport-cluster", "eks/aws-load-balancer-controller", "base", "gateway", "istiod", "aws-node-termination-handler", "appsmith", "velero", "oauth2-proxy", "superset", "dante", "k8s-pod-restart-info-collector", "cost-analyzer", "community-operator", "aws-efs-csi-driver"]
}



resource "aws_ecr_repository" "helm_ecr_repositories" {
  count = length(local.helm_charts)
  name                 = "chart-${local.helm_charts[count.index]}"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = data.terraform_remote_state.shared_infra.outputs.ecr_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "${local.helm_charts[count.index]}-ecr"}))

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "allow_accounts_to_read_helm_charts" {
    count = length(local.helm_charts)
    policy      = <<EOT
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "new statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
         "${local.prod_application_account_id}" ,
         "${local.stage_application_account_id}" ,
         "${local.uat_application_account_id}",
         "${local.upswing_stage_application_account_id}"
          ]
      },
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:DescribeImages"
      ]
    }
  ]
}
EOT
    repository  = "chart-${local.helm_charts[count.index]}"
    depends_on = [
      aws_ecr_repository.helm_ecr_repositories
    ]
}


resource "aws_ecr_repository" "helm_ecr_repositories_2" {
  count = length(local.helm_charts_2)
  name                 = "${local.helm_charts_2[count.index]}"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = data.terraform_remote_state.shared_infra.outputs.ecr_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "${local.helm_charts_2[count.index]}-ecr"}))

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "allow_accounts_to_read_helm_charts_2" {
    count = length(local.helm_charts_2)
    policy      = <<EOT
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "new statement",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
         "${local.prod_application_account_id}" ,
         "${local.stage_application_account_id}" ,
         "${local.uat_application_account_id}",
         "${local.upswing_stage_application_account_id}"
          ]
      },
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:DescribeImages"
      ]
    }
  ]
}
EOT
    repository  = "${local.helm_charts_2[count.index]}"
    depends_on = [
      aws_ecr_repository.helm_ecr_repositories_2
    ]
}
