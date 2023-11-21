locals {
      oidc_provider_url = "oidc.eks.ap-south-1.amazonaws.com/id/C91730AE4AA644A9810BCF9A2DB2F992"
      shared_infra_account_id =  lookup(var.account_mapping, "Shared-Infra", 0)
      tags = {
        Environment = "uat"
        Terraform = "true"
        sprinto = "Prod" 
    }
}

variable account_id {}
variable account_mapping {
    type = map(string)
}



data "terraform_remote_state" "uat_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/UAT-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

locals {
  uat_app_k8s_private1_subnet_id = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.id
  uat_app_k8s_private2_subnet_id = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private2_subnet.id
  vpc_uat_infra_1_id = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_id
}

resource "aws_eip" "uat_external_ingress_eip1" {
  vpc= true

  tags = merge(local.tags,tomap({"Name" = "uat-external-ingress-eip1"}))
}

resource "aws_eip" "uat_external_ingress_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-external-ingress-eip2"}))
}

resource "aws_eip" "uat_acs_eip1" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-acs-eip1"}))
}
resource "aws_eip" "uat_acs_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-acs-eip2"}))
}

resource "aws_eip" "uat_cde_external_ingress_eip1" {
  vpc= true

  tags = merge(local.tags,tomap({"Name" = "uat-cde-external-ingress-eip1"}))
}

resource "aws_eip" "uat_cde_external_ingress_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-cde-external-ingress-eip2"}))
}

resource "aws_eip" "uat_noncde_external_ingress_eip1" {
  vpc= true

  tags = merge(local.tags,tomap({"Name" = "uat-noncde-external-ingress-eip1"}))
}

resource "aws_eip" "uat_noncde_external_ingress_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "uat-noncde-external-ingress-eip2"}))
}


provider "github" {
    token = var.github_token
    owner = "upswing-one"
}




data "github_repository" "platform_configs" {
  full_name = "upswing-one/platform-configs"
}

data "github_repository_file" "envs" {
  repository          = data.github_repository.platform_configs.full_name
  branch              = "main"
  file                = "appInits/${local.variant}/envs.yml"
}

locals {
    envs = {for v in [local.variant]: v => [
        for env in yamldecode(data.github_repository_file.envs.content).envs: [env.name, v, env.cde]
    ]
        }
    
    env_set = concat(values(local.envs)...)
    #values like [[alpha, stage, false], [cde-alpha, stage, true]]
}


data "github_repository_file" "services" {
  repository          = data.github_repository.platform_configs.full_name
  branch              = "main"
  file                = "appInits/apps.yml"
}

locals {

  #Get Services from github yaml in format
  #apps:
  #- name: access-control-server
  #  cde: true
  #  variants:
  #    - stage
  #    - uat
  services = yamldecode(data.github_repository_file.services.content).apps

  #Filter out the services active for the given variant and the env
  #For all other env, set "" empty string
  service_env_set_unfiltered = concat([
    for e in local.env_set: [
      for s in local.services: concat([
        e],[ 
          contains(keys(s), "variants") ? contains(s.variants, e[1]) ? e[2] == s.cde ? s.name : "" : "" : e[2] == s.cde ? s.name : ""
      ])
    ]
  ]...)

  #To have all properties for a service like type
  service_env_set_unfiltered_with_all_props = concat([
    for e in local.env_set: [
      for s in local.services: concat([
        e],[ 
          contains(keys(s), "variants") ? contains(s.variants, e[1]) ? e[2] == s.cde ? s : null : null : e[2] == s.cde ? s : null
      ])
    ]
  ]...)
  #Filter out empty string to only have the active services
  service_env_set = [for e in local.service_env_set_unfiltered: e if e[1] != "" ]
  service_env_set_with_all_props = [for e in local.service_env_set_unfiltered_with_all_props: e if e[1] != null ]

  #Results in set like [[[alpha, stage, false], customer-service], [[cde-alpha, stage, true], access-control-server]]]
  service_env_map = {for e in local.service_env_set: "${e[0][0]}-${e[1]}" => e}
  
}

locals {
  variant = "uat"
}