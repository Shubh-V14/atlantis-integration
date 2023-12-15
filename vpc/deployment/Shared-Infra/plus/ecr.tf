
locals {
backend_services = [ "term-deposit-service", "payments-service","card-management-service", "card-personalisation-file-generation-service", "communications-service", "customer-service", "access-control-server", "switch-service", "tokenisation-service", "pam-service", "sdk-dynamic-bundle", "card-data-service", "entity-profile-service", "partner-integration-service", "frame-service", "lending-platform-service", "stage-api-toolkit-service", "edhas-backend-service", "customer-support-service", "acs-challenge-web", "acs-merchant-app", "acs-mock-ds", "connector-dashboard-web", "acs-dashboard-web", "webapp-router"]
}



resource "aws_ecr_repository" "backend_ecr_repositories" {
  count = length(local.backend_services)
  name                 = "b-${local.backend_services[count.index]}"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = data.terraform_remote_state.shared_infra.outputs.ecr_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "${local.backend_services[count.index]}-ecr"}))

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "allow_accounts_to_read_ecr" {
    count = length(local.backend_services)
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
         "${local.stage_application_account_id}",
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
    repository  = "b-${local.backend_services[count.index]}"
    depends_on = [
      aws_ecr_repository.backend_ecr_repositories
    ]
}

resource "aws_ecr_repository" "argocdproxy-app" {
  name                 = "argocdproxy-app"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = data.terraform_remote_state.shared_infra.outputs.ecr_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "allow_accounts_to_read_ecr-for-argocdproxy-app" {
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
         "${local.stage_application_account_id}",
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
    repository  = "argocdproxy-app"
}

resource "aws_ecr_repository" "backend-java" {
  name                 = "backend-java"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = data.terraform_remote_state.shared_infra.outputs.ecr_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "backend-java-ecr"}))

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "allow_accounts_to_read_ecr-for-backend-java" {
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
         "${local.stage_application_account_id}",
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
    repository  = "backend-java"
}

locals {
  images = ["clamav", "basic-fim", "alpine-k8s-python", "jenkins", "ci_1", "amazon-k8s-cni","amazon/aws-load-balancer-controller","eks/coredns","eks/kube-proxy","alpine","alpine/socat","apachepulsar/pulsar-all","apachepulsar/pulsar-manager","bitnami/kubectl","busybox","bitnami/keycloak","grafana/loki","grafana/promtail","istio/pilot","istio/proxyv2","kubeshark/front","kubeshark/hub","kubeshark/worker","nginxinc/nginx-unprivileged","heptio-images/eventrouter","kyverno/kyverno","grafana/grafana","hashicorp/vault-k8s","hashicorp/vault","autoscaling/cluster-autoscaler","metrics-server/metrics-server","sig-storage/csi-attacher","sig-storage/csi-node-driver-registrar","sig-storage/csi-provisioner","sig-storage/csi-resizer","sig-storage/livenessprobe","prom/blackbox-exporter","docker/library/redis","ebs-csi-driver/aws-ebs-csi-driver","gravitational/teleport","argoproj/argocd","jetstack/cert-manager-cainjector","jetstack/cert-manager-controller","jetstack/cert-manager-webhook","kiwigrid/k8s-sidecar","prometheus-operator/prometheus-config-reloader","prometheus-operator/prometheus-operator","prometheus/alertmanager","prometheus/node-exporter","prometheus/prometheus","kube-state-metrics/kube-state-metrics", "ingress-nginx/kube-webhook-certgen", "dump-collector", "grafana/mimir","memcached","prom/memcached-exporter","grafana/enterprise-metrics","docker.io/raintank/graphite-mt","grafana/mimir-continuous-test", "minio/minio", "grafana/rollout-operator", "grafana/agent-operator", "ci_terraform", "eks-distro/kubernetes-csi/external-provisioner", "eks-distro/kubernetes-csi/external-attacher", "eks-distro/kubernetes-csi/external-snapshotter/csi-snapshotter", "eks-distro/kubernetes-csi/livenessprobe", "eks-distro/kubernetes-csi/external-resizer", "eks-distro/kubernetes-csi/node-driver-registrar", "amazon/aws-cli", "kyverno/cleanup-controller", "oauth2-proxy/oauth2-proxy", "airflow", "aws-ec2/aws-node-termination-handler", "prometheus/statsd-exporter", "redis", "apache/airflow", "git-sync/git-sync", "bitnami/mongodb", "appsmith/appsmith-ce", "amazon/aws-efs-csi-driver", "velero/velero", "kedacore/keda", "kedacore/keda-metrics-apiserver", "apache/superset", "oneacrefund/superset-websocket", "bykva/dante", "curl", "kubecost1/kubecost-network-costs", "kubecost1/frontend", "kubecost1/cost-model", "bottlerocket-bootstrap", "mongo", "mongodb/mongodb-agent", "mongodb/mongodb-kubernetes-operator", "bitnami/redis", "mongodb/mongodb-kubernetes-operator-version-upgrade-post-start-hook", "mongodb/mongodb-kubernetes-readinessprobe", "keycloak/keycloak"]
}

resource "aws_ecr_repository" "repository" {
  count = length(local.images)
  name                 = local.images[count.index]
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = data.terraform_remote_state.shared_infra.outputs.ecr_key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "${local.images[count.index]}-ecr"}))
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "allow_accounts_to_read_ecr_images" {
    count = length(local.images)
    depends_on = [
      aws_ecr_repository.repository
    ]
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
         "${local.stage_application_account_id}",
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
    repository  = "${local.images[count.index]}"
}
