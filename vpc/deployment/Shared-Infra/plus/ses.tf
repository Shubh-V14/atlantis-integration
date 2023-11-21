
# aws_iam_role.ups_stage_idp_role:
resource "aws_iam_role" "ups_uat_ses_role" {
    assume_role_policy    =  <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${local.prod_application_account_id}",
          "${local.uat_application_account_id}"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOT
    description           = "ups-uat-ses-role"
    force_detach_policies = false

    # managed_policy_arns   = [
    #     "${aws_iam_policy.ups_stage_idp_policy.arn}"
    # ]
    max_session_duration  = 3600
    name                  = "ups-uat-ses-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_uat_ses_role_arn" {
    value = aws_iam_role.ups_uat_ses_role.arn
}


# aws_iam_role.ups_stage_idp_role:
resource "aws_iam_role" "ups_stage_ses_role" {
    assume_role_policy    =  <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${local.stage_application_account_id}"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOT
    description           = "ups-stage-ses-role"
    force_detach_policies = false

    # managed_policy_arns   = [
    #     "${aws_iam_policy.ups_stage_idp_policy.arn}"
    # ]
    max_session_duration  = 3600
    name                  = "ups-stage-ses-role"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "ups_stage_ses_role_arn" {
    value = aws_iam_role.ups_stage_ses_role.arn
}