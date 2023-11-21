resource "aws_key_pair" "k8s_ssh_key" {
   key_name   = "ankit's-key"
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQChU2gCBUWFVrDiHttKWXiYyqIty2H5jjKgZLFmvI9cf7VRtkRVif7Yeeyag7N5uhcnj5x6uHft1aRtQCY8RQNp80pwCDfAo+epXqZ4Zv0SqniQ13KF6lCvfr4UjbWOqvUL1VJew9Njyx1Khc+A4E5Nr031C152Wbukn2zgl8sPG8Jh/MPJ4zgroH2oIrftAfAbbdOTqFFpKKe2bisz/OnVwPk0cNUwNyGK3HNS/UgixdvscdhOUICu6TbT1zhLG3v6VXNvAVmOOFlwLpbStOoJTwkTGeQPvi7QVfE/e2H4c9g+Z05ACPyxxDUPnCYSohAtMnJvLuG39wMZ9xwa0Uelmqb+qRwL1PIch246Vwk1k7JIcB3p0BixuQvfEnfj62jIQ9tQsId8Go7fE7ckt+eNOnLrlm0h2dBDvCe5ZgQvtIQWdG1jt4Z8Gy7EuxywF8KKFC2qCEfEb3g9zwDBdw0ygOLPfMk8z1RgyI0roOxhiV8mUe/X0zjDQdgSYDls+gE= ankit.r@upswing"
 }


# resource "aws_security_group" "allow_ssh_k8s" {
#   name        = "k8s_allow_ssh"
#   description = "Allow ssh traffic within k8s"
#   vpc_id      = "vpc-055e4bdc8f4a441b8"

#   ingress {
#     description      = "SSH from VPC"
#     from_port        = 22
#     to_port          = 22
#     protocol         = "tcp"
#     cidr_blocks      = ["10.140.0.0/18"]
#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }

#   tags = {
#     Name = "k8s_allow_ssh"
#   }
# }

data "terraform_remote_state" "stage_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Stage-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"

  }
}


locals {
 stage_app_k8s_private1_cidr = data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private1_cidr
 stage_app_k8s_private2_cidr = data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private2_cidr
 stage_app_k8s_private1 = data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private1
 stage_app_k8s_private2 = data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private2
 vpc_stage_infra_1_id = data.terraform_remote_state.stage_infra.outputs.vpc_stage_infra_1_id
 stage_db1_vpc_id = data.terraform_remote_state.stage_infra.outputs.vpc_stage_db1_id
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
  variant = "stage"
}

resource "aws_eip" "stage_app_external_eip" {
  count = length([1,2])
  vpc= true

  tags = merge(local.tags,tomap({"Name" = "stage-app-external-eip${count.index}"}))
}

output "stage_app_external_eips" {
  value = aws_eip.stage_app_external_eip[*].allocation_id
}

variable account_mapping {
  type = map(string)
}

locals {
    upswing_stage_application_account_id = lookup(var.account_mapping, "Upswing-Stage-Application", 0)
}