variable account_id {}

locals {
    variant = "stage"
    tags = {
      Environment = local.variant
      Terraform = "true"
    }
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

data "terraform_remote_state" "stage_account" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Stage-Application/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

data "terraform_remote_state" "stage_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Upswing-Stage-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

locals {
  oidc_provider_arn = module.stage1_eks.oidc_provider_arn
  oidc_provider_url = module.stage1_eks.oidc_provider_url
}