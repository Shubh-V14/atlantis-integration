data "aws_iam_policy" "administrator_access" {
  name = "AdministratorAccess"
}

locals {
      tags = {
      Environment = "prod"
      Terraform = "true"
      sprinto = "Prod" 
    }
}

 resource "aws_iam_role" "tf_role" {
     description           = "tf-role"
     force_detach_policies = false
     assume_role_policy = <<EOT
 {
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Principal": {
         "AWS": ${jsonencode(concat(sort(jsondecode(var.org_arns)),["arn:aws:iam::199381154999:role/tf-ws"]))}
       },
       "Action": "sts:AssumeRole"
     }
   ]
 }
 EOT
     managed_policy_arns   = [
         "${data.aws_iam_policy.administrator_access.arn}"
     ]
     max_session_duration  = 3600
     name                  = "tf-role"
     path                  = "/"
     tags                  = {}
     tags_all              = {}

 }


 output "tf_role_arn" {
     value = aws_iam_role.tf_role.arn
 }

variable account_id {
type = string
}

variable org_arns {}
