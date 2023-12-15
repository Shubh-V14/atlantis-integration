provider "github" {
    token = var.github_token
    owner = "upswing-one"
}

data "github_repository" "employee_configs" {
  full_name = "upswing-one/employee-configs"
}

data "github_repository_file" "users" {
  repository          = data.github_repository.employee_configs.full_name
  branch              = "main"
  file                = "userConfigs/users.yaml"
}

locals {
  users =  yamldecode(data.github_repository_file.users.content)
}

data "aws_ssoadmin_instances" "main" {}

#Set IAM Identity User
resource "aws_identitystore_user" "main" {
  for_each = local.users
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]

  display_name = format("%s %s", each.value["firstname"], each.value["lastname"])
  user_name    = each.value["email"]

  name {
    given_name  = each.value["firstname"]
    family_name = each.value["lastname"]
  }

  emails {
    value = each.value["email"]
    primary = true
    type = "work"
  }
}

resource "aws_identitystore_group" "ups_dev_3" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  display_name      = "UPS-DEV-3"
  description       = "upswing developer default group"
}

resource "aws_identitystore_group_membership" "main" {
  for_each = local.users
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  group_id          = aws_identitystore_group.ups_dev_3.group_id
  member_id         = aws_identitystore_user.main[each.key].user_id
}



