# # aws_security_group.client_vpn1_sg:
# resource "aws_security_group" "mci_sg" {
#     description = "mci instance sg"
#     egress      = [
#         {
#             cidr_blocks      = [
#                 "0.0.0.0/0",
#             ]
#             description      = "for mci egress"
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
#             cidr_blocks      = ["10.0.0.0/8"]
#             description      = "for mci"
#             from_port        = 3000
#             to_port          = 4003
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "tcp"
#             security_groups  = []
#             self             = false
#         },
#          {
#             cidr_blocks      = ["10.0.0.0/8"]
#             description      = "for mci portal"
#             from_port        = 443
#             to_port          = 443
#             ipv6_cidr_blocks = []
#             prefix_list_ids  = []
#             protocol         = "tcp"
#             security_groups  = []
#             self             = false
#         },
#     ]
#     name        = "myhsm mci instance sg"
#     tags = merge(local.tags,tomap({"Name" = "mci"}))
#     tags_all    = {}
#     vpc_id      = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_id
# }

# # resource "aws_ebs_volume" "mci_volume1" {
# #     availability_zone = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.availability_zone
# #     size = 80
# #     tags = merge(local.tags,tomap({"Name" = "mci"}))
# #     kms_key_id = aws_kms_key.ebs_key.arn
# #     encrypted = true
# # }

# resource "aws_iam_policy" "allow_kms_for_mci" {
#     description = "mci-ec2-permissions"
#     name        = "mci-ec2-permissions"
#     policy      = <<EOT
# {
#   "Version": "2012-10-17",
#   "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "kms:*"
#             ],
#             "Resource": "*"
#         }
#   ]
# }
# EOT
#     tags = merge(local.tags,tomap({"Name" = "mci-kms"}))
#     tags_all    = {}
# }

# resource "aws_iam_role_policy_attachment" "mci_policy_attachment" {
#   role       = aws_iam_role.mci_instance_role.id
#   policy_arn = aws_iam_policy.allow_kms_for_mci.arn
# }

# resource "aws_iam_role" "mci_instance_role" {
#   name = "mci-instance-role"
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
# resource "aws_iam_role_policy_attachment" "mci-ssm-permissions" {
#   role       = aws_iam_role.mci_instance_role.id
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# resource "aws_iam_instance_profile" "mci_instance_profile" {
#   name = "mci-instance-profile"
#   role = aws_iam_role.mci_instance_role.name
# }

# module "mci_ec2" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-031b363c3bcc254a2"
#   instance_type = "t3.medium"
#   subnet_id     = data.terraform_remote_state.uat_infra.outputs.uat_cde_private1_subnet.id
#   vpc_security_group_ids = [aws_security_group.mci_sg.id]

#   #Setting the profile so that this Instance is managed through SSM
#   iam_instance_profile = aws_iam_instance_profile.mci_instance_profile.name
  
#   tags = merge(local.tags,tomap({"Name" = "mci"}))
#   volume_tags = merge(local.tags,tomap({"Name" = "mci"}))
# }

# # resource "aws_volume_attachment" "attach_ebs_to_kali_linux" {
# #   device_name = "/dev/sdh"
# #   volume_id   = aws_ebs_volume.mci_volume1.id
# #   instance_id = module.mci.id
# # }
