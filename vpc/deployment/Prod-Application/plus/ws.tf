
# aws_security_group.client_vpn1_sg:
resource "aws_security_group" "noncde_ws_sg" {
    description = "noncde ws instance sg"
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
    name        = "noncde ws instance sg"
    tags = merge(local.tags,tomap({"Name" = "noncde-ws"}))
    tags_all    = {}
    vpc_id      = data.terraform_remote_state.prod_infra.outputs.vpc_prod_noncde_infra_1_id
}

resource "aws_ebs_volume" "noncde_ws_volume1" {
    availability_zone = data.terraform_remote_state.prod_infra.outputs.prod_noncde_private1_subnet.availability_zone
    size = 80
    tags = merge(local.tags,tomap({"Name" = "noncde-ws"}))
    kms_key_id = aws_kms_key.ebs_key.arn
    encrypted = true
}

module "noncde_ws" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.2.0"

  ami           = "ami-0cca134ec43cf708f"
  instance_type = "t3.medium"
  subnet_id     =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private1_subnet.id
  vpc_security_group_ids = [aws_security_group.noncde_ws_sg.id]

  #Setting the profile so that this Instance is managed through SSM
  iam_instance_profile = aws_iam_instance_profile.allow_ec2_session.name
  
  tags = merge(local.tags,tomap({"Name" = "noncde-ws"}))
  volume_tags = merge(local.tags,tomap({"Name" = "noncde-ws"}))
  key_name = "temp"
}

resource "aws_volume_attachment" "attach_ebs_to_kali_linux" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.noncde_ws_volume1.id
  instance_id = module.noncde_ws.id
}