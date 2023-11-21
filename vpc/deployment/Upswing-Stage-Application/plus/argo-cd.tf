#Provide secret and add github and keycloak secrets

variable argocd_github_secret {
  type = string
  default = null
}

variable argocd_keycloak_secret {
  type = string
  default = null
}

variable argocd_admin_password {
  type = string
  default = ""
}

variable argocd_values_file {
  default = "argocd-values.yaml"
}


locals {
  release_name = "argocd"
  namespace = "argocd"
  argocd_chart_version = "5.46.6"
  insecure = true
  admin_password = var.argocd_admin_password
  timeout_seconds = 120
  set_admin_pass = var.argocd_admin_password == "" ? []: [1]
}

module "this" {
  source  = "cloudposse/label/null"
  namespace  = "redis"
  stage      = "stage"
  name       = "stage1"
}

#todo update back eks node sg
module "redis" {
  source = "cloudposse/elasticache-redis/aws"

  vpc_id                     = local.infra1_vpc_id
  subnets                    = [local.subnet_ids_for_nodegroup1[0]]
  cluster_size               = 1
  instance_type              = "cache.t4g.medium"
  apply_immediately          = true
  automatic_failover_enabled = false
  engine_version             = "7.0"
  family                     = "redis7"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  create_security_group = true
  additional_security_group_rules = [
    {
    key         = "allow-vpc1"
    type        = "ingress"
    from_port   = "6379"
    to_port     = "6379"
    protocol    = "tcp"
    cidr_blocks = [local.infra1_vpc_cidr_block]
    description = "Allow inbound traffic from CIDR blocks"
  }
  ]
  description = "stage1"
  parameter = [
    {
      name  = "notify-keyspace-events"
      value = "lK"
    }
  ]
  context = module.this.context
}

provider "helm" {
  alias = "helm"
  kubernetes {
    host                   = module.stage1_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.stage1_eks.cluster_certificate_authority_data)
    token = data.aws_eks_cluster_auth.main.token
  }
}

resource "helm_release" "argocd" {
  provider = helm.helm
  namespace        = local.namespace
  create_namespace = true
  name             = local.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = local.argocd_chart_version

  # Helm chart deployment can sometimes take longer than the default 5 minutes
  timeout = local.timeout_seconds

  # If values file specified by the var.values_file input variable exists then apply the values from this file
  # else apply the default values from the chart
  values = [fileexists("${path.root}/${var.argocd_values_file}") == true ? file("${path.root}/${var.argocd_values_file}") : ""]


  set {
    name = "externalRedis.host"
    value = module.redis.endpoint
  }

  dynamic "set_sensitive" {
    for_each = local.set_admin_pass
    content {
      name  = "configs.secret.argocdServerAdminPassword"
      value = bcrypt(local.admin_password)
    }
  }
  
  #These secret is only supported from main secret which is updated via this config
  #For other apps/charts, if support is there, choose to set different secret and read from it
  set_sensitive {
      name  = "configs.secret.githubSecret"
      value = local.argocd_secrets_data["webhook.github.secret"]
  }
  set_sensitive {
      name  = "configs.secret.extra.keycloak_client_secret"
      value = local.argocd_secrets_data["oidc.keycloak.clientSecret"]
      type = "auto"
  }

}



data "kubernetes_secret_v1" "argocd" {
  metadata {
    name = "argocd-secret"
    namespace = "argocd"
  }
  depends_on = [ helm_release.argocd]
}



#This will only add the field if not present as existing data is going to override
#Thus only useful for first time update of the secret


locals {
  argocd_secrets_value = jsondecode(module.argocd_secret.secret_binary)
  argocd_secrets_keys = ["oidc.keycloak.clientSecret", "webhook.github.secret"]

  argocd_secrets_data = {for k in local.argocd_secrets_keys: k => local.argocd_secrets_value[k] if lookup(local.argocd_secrets_value, k, false) != false ? true : false}

  argocd_private_repo_key = lookup(local.argocd_secrets_value, "git.key", null)
}

locals {
  repos_to_sync_from = [
    "git@github.com:upswing-one/infra-argocd-applications.git",
    "git@github.com:upswing-one/infra-env-config-prod.git",
    "git@github.com:upswing-one/infra-env-config-stage.git",
    "git@github.com:upswing-one/k8s-configs-stage.git",
    "git@github.com:upswing-one/k8s-configs-prod.git",
    "git@github.com:upswing-one/app-deployment-config-stage.git",
    "git@github.com:upswing-one/app-deployment-config-prod.git",
    "git@github.com:upswing-one/platform-configs.git"
  ]
}

resource "kubectl_manifest" "private_repo_secret" {
  depends_on = [helm_release.argocd ]
  count = length(local.repos_to_sync_from)
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-${count.index}
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${local.repos_to_sync_from[count.index]}
  sshPrivateKey: |
    ${indent(4, base64decode(local.argocd_private_repo_key))}
YAML
}

resource "kubectl_manifest" "app_project_backend" {
  depends_on = [helm_release.argocd ]
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: backend
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  destinations:
  - name: '*'
    namespace: '*'
    server: '*'
  orphanedResources:
    warn: true
  roles:
  - description: devs
    groups:
    - /devs
    name: devs
    policies:
    - p, proj:backend:devs, applications, sync, backend/*, allow
    - p, proj:backend:devs, applications, update, backend/*, allow
    - p, proj:backend:devs, applications, get, backend/*, allow
    - p, proj:backend:devs, applications, action/apps/*/restart, backend/*, allow
  sourceRepos:
  - '*'
YAML
}


resource "kubectl_manifest" "app_project_configs" {
  depends_on = [helm_release.argocd ]
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: configs
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  description: configs
  destinations:
  - name: '*'
    namespace: '*'
    server: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  roles:
  - description: configs
    groups:
    - /devs
    name: devs
    policies:
    - p, proj:configs:devs, applications, sync, configs/*, allow
    - p, proj:configs:devs, applications, update, configs/*, allow
    - p, proj:configs:devs, applications, action/apps/*/restart, configs/*, allow
    - p, proj:configs:devs, applications, get, configs/*, allow
  sourceRepos:
  - '*'
YAML
}

resource "kubectl_manifest" "app_project_charts" {
  depends_on = [helm_release.argocd ]
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: charts
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  description: charts
  destinations:
  - name: '*'
    namespace: '*'
    server: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  roles:
  - groups:
    - /admins
    name: admin
    policies:
    - p, proj:charts:admin, applications, *, charts/*, allow
  - description: devs
    groups:
    - /devs
    name: devs
    policies:
    - p, proj:charts:devs, applications, get, charts/*, allow
    - p, proj:charts:devs, applications, sync, charts/*, allow
    - p, proj:charts:devs, applications, update, charts/*, allow
    - p, proj:charts:devs, applications, action/apps/*/restart, charts/*, allow
  sourceRepos:
  - '*'
YAML
}

resource "kubectl_manifest" "app_of_apps" {
  depends_on = [helm_release.argocd ]
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: "default"
  source:
    repoURL: 'git@github.com:upswing-one/infra-argocd-applications.git'
    targetRevision: main
    path: ./stage2
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd


  syncPolicy:
    automated: # automated sync by default retries failed attempts 5 times with following delays between attempts ( 5s, 10s, 20s, 40s, 80s ); retry controlled using `retry` field.
      prune: true # Specifies if resources should be pruned during auto-syncing ( false by default ).
      selfHeal: true # Specifies if partial app sync should be executed when resources are changed only in target Kubernetes cluster and no git change detected ( false by default ).
      allowEmpty: false # Allows deleting all application resources during automatic syncing ( false by default ).
    syncOptions:     # Sync options which modifies sync behavior
    - Validate=true # disables resource validation (equivalent to 'kubectl apply --validate=false') ( true by default ).
    - CreateNamespace=false # Namespace Auto-Creation ensures that namespace specified as the application destination exists in the destination cluster.
    - PrunePropagationPolicy=foreground # Supported policies are background, foreground and orphan.
    - PruneLast=true # Allow the ability for resource pruning to happen as a final, implicit wave of a sync operation
    # The retry feature is available since v1.7
    retry:
      limit: 5 # number of failed sync attempt retries; unlimited number of attempts if less than 0
      backoff:
        duration: 5s # the amount to back off. Default unit is seconds, but could also be a duration (e.g. "2m", "1h")
        factor: 2 # a factor to multiply the base duration after each failed retry
        maxDuration: 3m # the maximum amount of time allowed for the backoff s
YAML
}

resource kubectl_manifest "helm_repo_add" {
  depends_on = [helm_release.argocd ]
  yaml_body = <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: helm-repo-add
  namespace: argocd
spec:
  template:
    spec:
      containers:
      - command:
        - /bin/bash
        - -ce
        - |-
          kubectl -n argocd create secret docker-registry $SECRET_NAME \
            --dry-run=client \
            --docker-server="$ECR_REGISTRY" \
            --docker-username=AWS \
            --docker-password="$(</token/ecr-token)" \
            -o yaml | kubectl apply -f - && \
          cat <<EOF | kubectl apply -f -
          apiVersion: v1
          kind: Secret
          metadata:
            name: argocd-ecr-helm-credentials
            namespace: argocd
            labels:
              argocd.argoproj.io/secret-type: repository
          stringData:
            type: helm
            name: chart-backend
            url: 776633114724.dkr.ecr.ap-south-1.amazonaws.com
            enableOCI: "true"
            username: AWS
            password: $(</token/ecr-token)
          EOF
        env:
        - name: SECRET_NAME
          value: ecr-credentials
        - name: ECR_REGISTRY
          value: 776633114724.dkr.ecr.ap-south-1.amazonaws.com
        image: 776633114724.dkr.ecr.ap-south-1.amazonaws.com/bitnami/kubectl
        imagePullPolicy: IfNotPresent
        name: create-secret
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /token
          name: token
      dnsPolicy: ClusterFirst
      initContainers:
      - command:
        - /bin/sh
        - -ce
        - aws ecr get-login-password --region ap-south-1 > /token/ecr-token
        env:
        - name: REGION
          value: ap-south-1
        image: 776633114724.dkr.ecr.ap-south-1.amazonaws.com/amazon/aws-cli
        imagePullPolicy: IfNotPresent
        name: get-token
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /token
          name: token
      restartPolicy: Never
      schedulerName: default-scheduler
      securityContext: {}
      serviceAccount: ecr-credentials-sync
      serviceAccountName: ecr-credentials-sync
      terminationGracePeriodSeconds: 30
      volumes:
      - emptyDir:
          medium: Memory
        name: token
YAML
}