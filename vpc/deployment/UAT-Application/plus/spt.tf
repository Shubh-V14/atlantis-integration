
# # aws_security_group.client_vpn1_sg:
# resource "aws_security_group" "spt_kali_sg" {
#     description = "spt kali instance sg"
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
#     ]
#     name        = "spt kali instance sg"
#     tags = merge(local.tags,tomap({"Name" = "spt-kali"}))
#     tags_all    = {}
#     vpc_id      = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_id
# }

# # aws_security_group.client_vpn1_sg:
# resource "aws_security_group" "spt_kali_sg_noncde_db" {
#     description = "spt kali instance sg noncde db"
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
#     ]
#     name        = "spt kali instance sg noncde db"
#     tags = merge(local.tags,tomap({"Name" = "spt-kali-noncde-db"}))
#     tags_all    = {}
#     vpc_id      = data.terraform_remote_state.uat_infra.outputs.vpc_uat_noncde_db_infra_id
# }

# locals {
#     spt_subnets = [
#     data.terraform_remote_state.uat_infra.outputs.uat_noncde_private1_subnet,
#     data.terraform_remote_state.uat_infra.outputs.uat_noncde_private2_subnet,
#     data.terraform_remote_state.uat_infra.outputs.uat_noncde_public1_subnet,
#     data.terraform_remote_state.uat_infra.outputs.uat_noncde_public2_subnet,
#     ]
#     spt_subnets_noncde_db = [
#         data.terraform_remote_state.uat_infra.outputs.uat_noncde_db1_private1_subnet,
#         data.terraform_remote_state.uat_infra.outputs.uat_noncde_db1_private2_subnet
#     ]
# }



# module "spt_kali" {
#   count = length(local.spt_subnets)
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-0ea5c3d241d65fd43"
#   instance_type = "t3.medium"
#   subnet_id     = local.spt_subnets[count.index].id
#   vpc_security_group_ids = [aws_security_group.spt_kali_sg.id]

#   #Setting the profile so that this Instance is managed through SSM
#   iam_instance_profile = aws_iam_instance_profile.allow_ec2_session.name
  
#   tags = merge(local.tags,tomap({"Name" = "spt-kali-${count.index}"}))
#   volume_tags = merge(local.tags,tomap({"Name" = "spt-kali-${count.index}"}))

# }

# output "spt_instance_id" {
#     value = module.spt_kali[*].arn
# }



# module "spt_kali_noncde_db" {
#   count = length(local.spt_subnets_noncde_db)
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-0ea5c3d241d65fd43"
#   instance_type = "t3.medium"
#   subnet_id     = local.spt_subnets_noncde_db[count.index].id
#   vpc_security_group_ids = [aws_security_group.spt_kali_sg_noncde_db.id]

#   #Setting the profile so that this Instance is managed through SSM
#   iam_instance_profile = aws_iam_instance_profile.allow_ec2_session.name
  
#   tags = merge(local.tags,tomap({"Name" = "spt-kali-noncde-db-${count.index}"}))
#   volume_tags = merge(local.tags,tomap({"Name" = "spt-kali-noncde-db-${count.index}"}))
# }

# output "spt_instance_noncde_db_id" {
#     value = module.spt_kali_noncde_db[*].arn
# }

# resource "aws_ebs_volume" "spt_kali_volume" {
#     count = length(local.spt_subnets)
#     availability_zone = local.spt_subnets[count.index].availability_zone
#     size = 80
#     tags = merge(local.tags,tomap({"Name" = "spt-kali-${count.index}"}))
#     kms_key_id = aws_kms_key.ebs_key.arn
#     encrypted = true
# }

# resource "aws_volume_attachment" "attach_ebs_to_spt_kali_linux" {
#   count = length(local.spt_subnets)
#   device_name = "/dev/sdg"
#   volume_id   = aws_ebs_volume.spt_kali_volume[count.index].id
#   instance_id = module.spt_kali[count.index].id
# }

# resource "aws_ebs_volume" "db_spt_kali_volume" {
#     count = length(local.spt_subnets_noncde_db)
#     availability_zone = local.spt_subnets_noncde_db[count.index].availability_zone
#     size = 80
#     tags = merge(local.tags,tomap({"Name" = "db-spt-kali-${count.index}"}))
#     kms_key_id = aws_kms_key.ebs_key.arn
#     encrypted = true
# }

# resource "aws_volume_attachment" "db_attach_ebs_to_spt_kali_linux" {
#   count = length(local.spt_subnets_noncde_db)
#   device_name = "/dev/sdg"
#   volume_id   = aws_ebs_volume.db_spt_kali_volume[count.index].id
#   instance_id = module.spt_kali_noncde_db[count.index].id
# }

#  # aws_iam_policy.allow_session_for_sisa_vapt:
#  resource "aws_iam_policy" "allow_session_for_sisa_spt" {
#      name      = "sisa-spt"
#      path      = "/"
#      policy    = jsonencode(
#          {
#              Statement = [
#                  {
#                      Action   = [
#                          "kms:GenerateDataKey",
#                      ]
#                      Effect   = "Allow"
#                      Resource = [
#                          "${aws_kms_key.ec2_session_key.arn}"
#                      ]
#                      Sid      = "VisualEditor0"
#                  },
#                    {
#                      Action   = [
#                          "kms:GenerateDataKey",
#                          "ssm:StartSession",
#                      ]
#                      Effect   = "Allow"
#                      Resource = concat(module.spt_kali[*].arn, module.spt_kali_noncde_db[*].arn)
#                      Sid      = "VisualEditor2"
#                  },
#                  {
#                   Effect = "Allow",
#                   Action = "ssm:StartSession",
#                   Resource = "arn:aws:ssm:ap-south-1::document/AWS-StartPortForwardingSession"
#                  },
#                  {
#                      Action   = [
#                          "ssm:GetConnectionStatus",
#                          "ssm:DescribeInstanceInformation",
#                      ]
#                      Effect   = "Allow"
#                      Resource = "*"
#                  },
#                  {
#                      Action   = [
#                          "ssm:ResumeSession",
#                          "ssm:TerminateSession",
#                      ]
#                      Effect   = "Allow"
#                      Resource = [
#                        "arn:aws:ssm:*:*:session/sisa-spt-*",
#                        "arn:aws:ssm:*:*:session/sisa-*"
#                      ]
#                      Sid      = "VisualEditor1"
#                  },
#              ]
#              Version   = "2012-10-17"
#          }
#      )
#  }

#  # aws_iam_user.sisa_vapt_user:
#  resource "aws_iam_user" "sisa_spt_user" {
#      name      = "sisa-spt"
#      path      = "/"
#  }

#  # aws_iam_user_policy_attachment.allow_kali_linux_for_sisa_vapt:
#  resource "aws_iam_user_policy_attachment" "allow_kali_linux_for_sisa_spt" {
#      policy_arn = aws_iam_policy.allow_session_for_sisa_spt.arn
#      user       = aws_iam_user.sisa_spt_user.name
#  }