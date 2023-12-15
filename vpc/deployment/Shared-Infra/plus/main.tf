locals {
    sprinto_prod_tags = {
      Environment = "Shared"
      Terraform = "true"
      sprinto = "Prod" 
    }
     sprinto_nonprod_tags = {
      Environment = "Shared"
      Terraform = "true"
      sprinto = "Prod" 
    }
   
}

resource "aws_vpc" "shared_infra_1" {
  ipv4_ipam_pool_id = "ipam-pool-0c6e642b4c8ad9e27"
  cidr_block       = "10.0.0.0/21"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "shared-infra-1"}))
}

output "shared_infra_1_id" {
  value = aws_vpc.shared_infra_1.id
}

output "shared_infra_1_cidr" {
  value = aws_vpc.shared_infra_1.cidr_block
}


data "terraform_remote_state" "shared_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Shared-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
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

data "terraform_remote_state" "upswing_stage_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Upswing-Stage-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

data "terraform_remote_state" "prod_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Prod-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}


# variable tf_state_key {}
# variable tg_profile {}

# data "terraform_remote_state" "shared_infra" {
#   backend = "s3"
#   config = {
#     bucket = "ups-infra-state"
#     key = var.tf_state_key
#     profile = var.tg_profile
#     region = "ap-south-1"
#   }
# }

locals {
  shared_infra_1_vpc_id = aws_vpc.shared_infra_1.id
  uat_infra_vpc_tgw_attachment_id = data.terraform_remote_state.uat_infra.outputs.uat_k8s_vpc_tgw_attachment_id
  stage_infra_app_k8s_private1_cidr = data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private1_cidr
  stage_infra_app_k8s_private2_cidr = data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private2_cidr


  upswing_stage_infra_cidr = data.terraform_remote_state.upswing_stage_infra.outputs.infra1_vpc_cidr_block

  uat_infra_app_k8s_private1_cidr = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_cidr
  uat_infra_app_k8s_private2_cidr = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private2_cidr

  uat_infra_app_k8s_public1_cidr = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_public1_subnet.cidr_block
  uat_infra_app_k8s_public2_cidr = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_public2_subnet.cidr_block

  uat_infra_cde_k8s_private1_cidr = data.terraform_remote_state.uat_infra.outputs.uat_cde_private1_cidr
  uat_infra_cde_k8s_private2_cidr = data.terraform_remote_state.uat_infra.outputs.uat_cde_private2_cidr

  uat_infra_noncde_k8s_private1_cidr = data.terraform_remote_state.uat_infra.outputs.uat_noncde_private1_cidr
  uat_infra_noncde_k8s_private2_cidr = data.terraform_remote_state.uat_infra.outputs.uat_noncde_private2_cidr
  prod_k8s_cluster_private1_cidr = data.terraform_remote_state.prod_infra.outputs.prod_k8s_cluster_private1_cidr
  prod_k8s_cluster_private2_cidr = data.terraform_remote_state.prod_infra.outputs.prod_k8s_cluster_private2_cidr
}

variable org_arns {}
variable account_id {}

variable account_mapping {
  type = map(string)
}

locals {
  prod_application_account_id = lookup(var.account_mapping, "Prod-Application", 0)
  stage_application_account_id = lookup(var.account_mapping, "Stage-Application", 0)
  uat_application_account_id = lookup(var.account_mapping, "UAT-Application", 0)
  upswing_stage_application_account_id = lookup(var.account_mapping, "Upswing-Stage-Application", 0)
}
