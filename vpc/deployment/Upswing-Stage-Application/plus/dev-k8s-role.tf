# aws_iam_role.stage_k8s_dev_3_role:
resource "aws_iam_role" "stage_k8s_dev_3_role" {
    assume_role_policy    =  <<EOT
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.account_id}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }
    ]
}
EOT
    description           = "stage-k8s-dev-3"
    force_detach_policies = false
    managed_policy_arns   = []
    max_session_duration  = 3600
    name                  = "stage-k8s-dev-3"
    tags                  = {}
    tags_all              = {}
}