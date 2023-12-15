# locals {
#     ws_linux_image_id = "ami-01216e7612243e0ef"
#     tags = {
#       Name = "ws-linux"
#       Environment = "shared"
#       Terraform = "true"
#     }
# }




# resource "aws_iam_role" "allow_ec2_session" {
#   name = "ec2-session"
#   assume_role_policy = jsonencode({
#     "Version" = "2012-10-17",
#     "Statement" = [
#       {
#         "Effect" = "Allow",
#         "Principal" = {
#           "Service" = "ec2.amazonaws.com"
#         },
#         "Action" = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# # required it seems
# resource "aws_iam_role_policy_attachment" "ec2-ssm-instance" {
#   role       = aws_iam_role.allow_ec2_session.id
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# # required it seems
# resource "aws_iam_role_policy_attachment" "ssm-ec2" {
#   role       = aws_iam_role.allow_ec2_session.id
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
# }

# resource "aws_iam_policy" "allow_kms_for_ec2_sessions" {
#     description = "ec2-session-kms-permissions"
#     name        = "ec2-session-kms-permissions"
#     policy      = <<EOT
# {
#   "Version": "2012-10-17",
#   "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "s3:PutObject"
#             ],
#             "Resource": "${aws_s3_bucket.ups_prod_ec2_session.arn}/*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "s3:GetEncryptionConfiguration"
#             ],
#             "Resource": "${aws_s3_bucket.ups_prod_ec2_session.arn}"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "kms:Decrypt"
#             ],
#             "Resource": "${aws_kms_key.ec2_session_key.arn}"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "kms:GenerateDataKey",
#             "Resource": "${aws_kms_key.ec2_session_key.arn}"
#         }
#   ]
# }
# EOT
#     tags        = {}
#     tags_all    = {}
# }

# resource "aws_iam_role_policy_attachment" "kms_policy_attachment" {
#   role       = aws_iam_role.allow_ec2_session.id
#   policy_arn = aws_iam_policy.allow_kms_for_ec2_sessions.arn
# }
# resource "aws_iam_instance_profile" "allow_ec2_session" {
#   name = "allow-ec2-session"
#   role = aws_iam_role.allow_ec2_session.name
# }

# # aws_security_group.client_vpn1_sg:
# resource "aws_security_group" "ipt_kali_sg" {
#     description = "ws instance sg"
#     egress      = [
#         {
#             cidr_blocks      = [
#                 "0.0.0.0/0",
#             ]
#             description      = ""
#             from_port        = 0
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "-1"
#             security_groups  = []
#             self             = false
#             to_port          = 0
#         },
#     ]
#     ingress     = [
#         {
#             cidr_blocks      = ["10.0.0.128/27", "10.0.0.96/27"]
#             description      = ""
#             from_port        = 22
#             to_port          = 22
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "tcp"
#             security_groups  = []
#             self             = false
#         },
#     ]
#     name        = "ipt kali instance sg"
#     tags        = {}
#     tags_all    = {}
#     vpc_id      = aws_vpc.shared_infra_1.id
# }

# resource "aws_ebs_volume" "ipt_kali_volume1" {
#     availability_zone = aws_subnet.ad_public1.availability_zone
#     size = 80
#     tags = local.tags
#     kms_key_id = aws_kms_key.ebs_key.arn
#     encrypted = true
# }

# module "ipt_kali" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-0bfc1a1fd13afcd7d"
#   instance_type = "t3.xlarge"
#   cpu_credits   = "unlimited"
#   subnet_id     = aws_subnet.ad_public1.id
#   vpc_security_group_ids = [aws_security_group.ipt_kali_sg.id]

#   #Setting the profile so that this Instance is managed through SSM
#   iam_instance_profile = aws_iam_instance_profile.allow_ec2_session.name
  
#   tags = local.tags
#   volume_tags = local.tags
# }

# resource "aws_volume_attachment" "attach_ebs_to_ws_linux" {
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.ipt_kali_volume1.id
#   instance_id = module.ipt_kali.id
# }

# # # aws_iam_policy.allow_session_for_sisa_vapt:
# # resource "aws_iam_policy" "allow_session_for_sisa_vapt" {
# #     name      = "sisa-vapt-test"
# #     path      = "/"
# #     policy    = jsonencode(
# #         {
# #             Statement = [
# #                 {
# #                     Action   = [
# #                         "kms:GenerateDataKey",
# #                         "ssm:StartSession",
# #                     ]
# #                     Effect   = "Allow"
# #                     Resource = [
# #                         "${aws_kms_key.ec2_session_key.arn}",
# #                         "${module.ipt_kali.arn}"
# #                     ]
# #                     Sid      = "VisualEditor0"
# #                 },
# #                 {
# #                     Action   = [
# #                         "ssm:GetConnectionStatus",
# #                         "ssm:DescribeInstanceInformation",
# #                     ]
# #                     Effect   = "Allow"
# #                     Resource = "*"
# #                 },
# #                 {
# #                     Action   = [
# #                         "ssm:ResumeSession",
# #                         "ssm:TerminateSession",
# #                     ]
# #                     Effect   = "Allow"
# #                     Resource = "arn:aws:ssm:*:*:session/sisa-vapt-test-*"
# #                     Sid      = "VisualEditor1"
# #                 },
# #             ]
# #             Version   = "2012-10-17"
# #         }
# #     )
# # }

# # # aws_iam_user.sisa_vapt_user:
# # resource "aws_iam_user" "sisa_vapt_user" {
# #     name      = "sisa-vapt-test"
# #     path      = "/"
# # }

# # # aws_iam_user_policy_attachment.allow_ws_linux_for_sisa_vapt:
# # resource "aws_iam_user_policy_attachment" "allow_ws_linux_for_sisa_vapt" {
# #     policy_arn = aws_iam_policy.allow_session_for_sisa_vapt.arn
# #     user       = aws_iam_user.sisa_vapt_user.name
# # }