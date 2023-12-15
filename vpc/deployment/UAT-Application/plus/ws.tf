
# aws_security_group.client_vpn1_sg:
resource "aws_security_group" "ws_sg" {
    description = "ws instance sg"
    egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    name        = "ws instance sg"
    tags = merge(local.tags,tomap({"Name" = "ws"}))
    tags_all    = {}
    vpc_id      = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_id
}

# resource "aws_ebs_volume" "ws_volume1" {
#     availability_zone = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.availability_zone
#     size = 80
#     tags = merge(local.tags,tomap({"Name" = "ws"}))
#     kms_key_id = aws_kms_key.ebs_key.arn
#     encrypted = true
# }

# module "ws" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "3.2.0"

#   ami           = "ami-0cca134ec43cf708f"
#   instance_type = "t3.medium"
#   subnet_id     =  data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.id
#   vpc_security_group_ids = [aws_security_group.ws_sg.id]

#   #Setting the profile so that this Instance is managed through SSM
#   iam_instance_profile = aws_iam_instance_profile.terraform_ws.name
  
#   tags = merge(local.tags,tomap({"Name" = "ws"}))
#   volume_tags = merge(local.tags,tomap({"Name" = "ws"}))
# }

# resource "aws_volume_attachment" "attach_ebs_to_ws" {
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.ws_volume1.id
#   instance_id = module.ws.id
# }


resource "aws_ebs_volume" "ws2_volume1" {
    availability_zone = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.availability_zone
    size = 80
    tags = merge(local.tags,tomap({"Name" = "ws2"}))
    kms_key_id = aws_kms_key.ebs_key.arn
    encrypted = true
}

module "ws2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.2.0"

  ami           = "ami-0cb6daa2a5d531add"
  instance_type = "t3.medium"
  subnet_id     =  data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.id
  vpc_security_group_ids = [aws_security_group.ws_sg.id]

  #Setting the profile so that this Instance is managed through SSM
  iam_instance_profile = aws_iam_instance_profile.terraform_ws.name
  
  tags = merge(local.tags,tomap({"Name" = "ws2"}))
  volume_tags = merge(local.tags,tomap({"Name" = "ws2"}))
}

resource "aws_volume_attachment" "attach_ebs_to_ws2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ws2_volume1.id
  instance_id = module.ws2.id
}