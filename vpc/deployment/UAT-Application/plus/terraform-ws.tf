 resource "aws_iam_role" "tf_ws" {
     description           = "tf-ws"
     force_detach_policies = false
    assume_role_policy = jsonencode({
        "Version" = "2012-10-17",
        "Statement" = [
        {
            "Effect" = "Allow",
            "Principal" = {
            "Service" = "ec2.amazonaws.com"
            },
            "Action" = "sts:AssumeRole"
        }
        ]
    })
     max_session_duration  = 3600
     name                  = "tf-ws"
     path                  = "/"
     tags                  = {}
     tags_all              = {}

 }

 output "tf_ws_arn" {
     value = aws_iam_role.tf_ws.arn
 }

resource "aws_iam_instance_profile" "terraform_ws" {
  name = "terraform-run"
  role = aws_iam_role.tf_ws.name
}

# required it seems
resource "aws_iam_role_policy_attachment" "tf_ws-ec2-ssm-instance" {
  role       = aws_iam_role.tf_ws.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# required it seems
resource "aws_iam_role_policy_attachment" "tg_ws_ssm-ec2" {
  role       = aws_iam_role.tf_ws.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_role_policy_attachment" "tf_ws_kms_policy_attachment" {
  role       = aws_iam_role.tf_ws.id
  policy_arn = aws_iam_policy.allow_kms_for_ec2_sessions.arn
}


resource "aws_iam_role_policy_attachment" "tf_assume_role" {
  role       = aws_iam_role.tf_ws.id
  policy_arn = aws_iam_policy.tf_assume_role.arn
}

variable "tf_role_arns" {
    type = list(string)
}
resource "aws_iam_policy" "tf_assume_role" {
     name      = "tf-assume-role"
     path      = "/"
     policy    = jsonencode(
         {
             Statement = [
                 {
                     Action   = [
                         "sts:AssumeRole",
                     ]
                     Effect   = "Allow"
                     Resource = var.tf_role_arns
                     Sid      = "VisualEditor0"
                 },
                   {
                     Action   = [
                         "sts:AssumeRole",
                     ]
                     Effect   = "Allow"
                     Resource = "arn:aws:iam::776633114724:role/tf-state-manager"
                     Sid      = "VisualEditor1"
                 },
                {
                     Action   = [
                         "sts:AssumeRole",
                     ]
                     Effect   = "Allow"
                     Resource = "arn:aws:iam::776633114724:role/tf-idp-state-manager"
                     Sid      = "VisualEditor2"
                 },
 {
                     Action   = [
                         "sts:AssumeRole",
                     ]
                     Effect   = "Allow"
                     Resource = "arn:aws:iam::776633114724:role/tf-github-state-manager"
                     Sid      = "VisualEditor3"
                 },


                      {
      "Effect": "Allow",
      "Action": [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::ups-infra-state",
        "arn:aws:s3:::ups-infra-state/*"
      ]
    }
     ]
             Version   = "2012-10-17"
         }
     )
 }
