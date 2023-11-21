include "root" {
  path = find_in_parent_folders()
}

locals {
    password_config = read_terragrunt_config("password.hcl")
    account_config = read_terragrunt_config("${path_relative_from_include()}/account-mapping.hcl")

}

inputs = {
  password_mapping = local.password_config.inputs.password_mapping
  tf_role_arns = [
    for name, id in local.account_config.inputs.account_mapping : {
      arn = "arn:aws:iam::${id}:role/tf-role"
    }
  ][*].arn
  tf_state_role_arns = [
    for name, id in local.account_config.inputs.account_mapping : {
      arn = "arn:aws:iam::${id}:role/tf-role"
    }
  ][*].arn
  }
