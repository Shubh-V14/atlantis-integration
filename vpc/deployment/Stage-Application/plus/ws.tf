
# # aws_security_group.client_vpn1_sg:
# resource "aws_security_group" "ws_sg" {
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
#     name        = "ws instance sg"
#     tags = merge(local.tags,tomap({"Name" = "ws"}))
#     tags_all    = {}
#     vpc_id      = local.vpc_stage_infra_1_id
# }


# module "ws" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-072ec8f4ea4a6f2cf"
#   instance_type = "t3.medium"
#   subnet_id     =  data.terraform_remote_state.stage_infra.outputs.stage_app_k8s_private1.id
#   vpc_security_group_ids = [aws_security_group.ws_sg.id]

#   #Setting the profile so that this Instance is managed through SSM
#   iam_instance_profile = aws_iam_instance_profile.terraform_ws.name
  
#   tags = merge(local.tags,tomap({"Name" = "ws"}))
#   volume_tags = merge(local.tags,tomap({"Name" = "ws"}))
# }

#  resource "aws_iam_role" "tf_ws" {
#      description           = "tf-ws"
#      force_detach_policies = false
#     assume_role_policy = jsonencode({
#         "Version" = "2012-10-17",
#         "Statement" = [
#         {
#             "Effect" = "Allow",
#             "Principal" = {
#             "Service" = "ec2.amazonaws.com"
#             },
#             "Action" = "sts:AssumeRole"
#         }
#         ]
#     })
#      max_session_duration  = 3600
#      name                  = "tf-ws"
#      path                  = "/"
#      tags                  = {}
#      tags_all              = {}

#  }

#  output "tf_ws_arn" {
#      value = aws_iam_role.tf_ws.arn
#  }

# resource "aws_iam_instance_profile" "terraform_ws" {
#   name = "terraform-run"
#   role = aws_iam_role.tf_ws.name
# }

# # required it seems
# resource "aws_iam_role_policy_attachment" "tf_ws-ec2-ssm-instance" {
#   role       = aws_iam_role.tf_ws.id
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }