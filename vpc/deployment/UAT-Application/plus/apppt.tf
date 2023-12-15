
# aws_security_group.client_vpn1_sg:
resource "aws_security_group" "apppt_windows_sg" {
    description = "apppt windows instance sg"
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
    ingress     = [
        {
            cidr_blocks      = ["182.73.209.102/32", "10.0.0.0/8"]
            description      = ""
            from_port        = 3389
            to_port          = 3389
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
        }
    ]
    name        = "apppt windows instance sg"
    tags = merge(local.tags,tomap({"Name" = "apppt-windows"}))
    tags_all    = {}
    vpc_id      = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_id
}

resource "aws_ebs_volume" "apppt_windows_volume1" {
    availability_zone = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.availability_zone
    size = 80
    tags = merge(local.tags,tomap({"Name" = "apppt-windows"}))
    kms_key_id = aws_kms_key.ebs_key.arn
    encrypted = true
}

module "apppt_windows" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.2.0"

  ami           = "ami-072b0ca48713abe5a"
  instance_type = "m5.xlarge"
  subnet_id     = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.id
  vpc_security_group_ids = [aws_security_group.apppt_windows_sg.id]

  #Setting the profile so that this Instance is managed through SSM
  iam_instance_profile = aws_iam_instance_profile.allow_ec2_session.name
  
  tags = merge(local.tags,tomap({"Name" = "apppt-windows"}))
  volume_tags = merge(local.tags,tomap({"Name" = "apppt-windows"}))
  key_name = "uat-ec2-key1"

}

resource "aws_volume_attachment" "attach_ebs_to_windows" {
  device_name = "xvdf"
  volume_id   = aws_ebs_volume.apppt_windows_volume1.id
  instance_id = module.apppt_windows.id
}