resource "aws_iam_role" "allow_ec2_session" {
  name = "ec2-session"
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
}

# required it seems
resource "aws_iam_role_policy_attachment" "ec2-ssm-instance" {
  role       = aws_iam_role.allow_ec2_session.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# required it seems
resource "aws_iam_role_policy_attachment" "ssm-ec2" {
  role       = aws_iam_role.allow_ec2_session.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_policy" "allow_kms_for_ec2_sessions" {
    description = "ec2-session-kms-permissions"
    name        = "ec2-session-kms-permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "${aws_s3_bucket.ups_uat_ec2_session.arn}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetEncryptionConfiguration"
            ],
            "Resource": "${aws_s3_bucket.ups_uat_ec2_session.arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "${aws_kms_key.ec2_session_key.arn}"
        },
        {
            "Effect": "Allow",
            "Action": "kms:GenerateDataKey",
            "Resource": "${aws_kms_key.ec2_session_key.arn}"
        },
        {
   "Effect": "Allow",
   "Action": [
       "kms:Encrypt",
       "kms:Decrypt",
       "kms:ReEncrypt*",
       "kms:GenerateDataKey*",
       "kms:DescribeKey",
       "kms:CreateGrant" 

   ],
   "Resource": "${aws_kms_key.ebs_key.arn}"
}
  ]
}
EOT
    tags = merge(local.tags,tomap({"Name" = "ipt-kali"}))
    tags_all    = {}
}

resource "aws_iam_role_policy_attachment" "kms_policy_attachment" {
  role       = aws_iam_role.allow_ec2_session.id
  policy_arn = aws_iam_policy.allow_kms_for_ec2_sessions.arn
}
resource "aws_iam_instance_profile" "allow_ec2_session" {
  name = "allow-ec2-session"
  role = aws_iam_role.allow_ec2_session.name
}


resource "aws_s3_bucket" "ups_uat_ec2_session" {
    bucket                      = "ups-uat-ec2-session"
    object_lock_enabled         = false


    tags = merge(local.tags,tomap({"Name" = "ups-uat-ec2-session"}))

}

resource "aws_s3_bucket_server_side_encryption_configuration" "uat_ec2_session_storage" {
    bucket = aws_s3_bucket.ups_uat_ec2_session.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.ec2_session_key.arn
        }
    }
    depends_on = [
        aws_kms_key.ec2_session_key
    ]
}