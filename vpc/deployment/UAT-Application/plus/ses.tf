resource "aws_iam_policy" "ses_permissions" {
    description = "ses-permissions"
    name        = "ses-permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": "arn:aws:iam::776633114724:role/ups-uat-ses-role",
      "Action": "sts:AssumeRole"
    }
  ]
}
EOT
    tags        = {}
    tags_all    = {}
}

