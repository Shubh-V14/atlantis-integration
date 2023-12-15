

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