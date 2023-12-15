# resource "aws_ssm_document" "ad_join_domain" {
#   name          = "ad-join-domain"
#   document_type = "Command"
#   content = jsonencode(
#     {
#       "schemaVersion" = "2.2"
#       "description"   = "aws:domainJoin"
#       "mainSteps" = [
#         {
#           "action" = "aws:domainJoin",
#           "name"   = "domainJoin",
#           "inputs" = {
#             "directoryId"    = "d-9f672d7cbd"
#             "directoryName"  = "corp.upswing.internal"
#             "dnsIpAddresses" = ["10.0.0.49", "10.0.0.28"]
#           }
#         }
#       ]
#     }
#   )
# }

# resource "aws_ssm_association" "windows_server" {
#   name = aws_ssm_document.ad_join_domain.name
#   targets {
#     key    = "tag:adjoin"
#     values = ["true"]
#   }
# }


# resource "aws_iam_role" "ad_autojoin" {
#   name = "ad-autojoin"
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
# resource "aws_iam_role_policy_attachment" "ssm-instance" {
#   role       = aws_iam_role.ad_autojoin.id
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# # required it seems
# resource "aws_iam_role_policy_attachment" "ssm-ad" {
#   role       = aws_iam_role.ad_autojoin.id
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
# }

# resource "aws_iam_instance_profile" "ad_autojoin" {
#   name = "ad-autojoin"
#   role = aws_iam_role.ad_autojoin.name
# }

# locals {
#   ec2-tags = {
#     Environment = "Shared"
#     "corp.upswing.internal-mgmt" = ""
#   }
# }

# module "ec2-instance" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-0b02eacf129bfac4e" 
#   instance_type = "t3.small"
#   cpu_credits   = "unlimited"
#   subnet_id     = aws_subnet.ad_private1.id

#   # THIS IS WHAT WE NEED TO AUTO_JOIN!! :))
#   iam_instance_profile = aws_iam_instance_profile.ad_autojoin.name
#   tags                 = merge({ "adjoin" = "true" }, local.ec2-tags)

#   key_name               = "ups-windows-dc1"

# }