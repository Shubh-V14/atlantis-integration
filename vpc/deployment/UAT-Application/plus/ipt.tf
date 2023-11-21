
# aws_security_group.client_vpn1_sg:
resource "aws_security_group" "ipt_kali_sg" {
    description = "ipt kali instance sg"
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
            from_port        = 3390
            to_port          = 3390
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
        },
         {
            cidr_blocks      = ["10.0.0.0/8"]
            description      = ""
            from_port        = 22
            to_port          = 22
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
        },
    ]
    name        = "ipt kali instance sg"
    tags = merge(local.tags,tomap({"Name" = "ipt-kali"}))
    tags_all    = {}
    vpc_id      = data.terraform_remote_state.uat_infra.outputs.vpc_uat_infra_1_id
}

resource "aws_ebs_volume" "ipt_kali_volume1" {
    availability_zone = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.availability_zone
    size = 80
    tags = merge(local.tags,tomap({"Name" = "ipt-kali"}))
    kms_key_id = aws_kms_key.ebs_key.arn
    encrypted = true
}

module "ipt_kali" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "3.2.0"

  ami           = "ami-083ecd8a439323552"
  instance_type = "m5.xlarge"
  subnet_id     = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_subnet.id
  vpc_security_group_ids = [aws_security_group.ipt_kali_sg.id]

  #Setting the profile so that this Instance is managed through SSM
  iam_instance_profile = aws_iam_instance_profile.allow_ec2_session.name
  
  tags = merge(local.tags,tomap({"Name" = "ipt-kali"}))
  volume_tags = merge(local.tags,tomap({"Name" = "ipt-kali"}))
  key_name = "uat-ec2-key1"

}

resource "aws_volume_attachment" "attach_ebs_to_kali_linux" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ipt_kali_volume1.id
  instance_id = module.ipt_kali.id
}

 # aws_iam_policy.allow_session_for_sisa_vapt:
 resource "aws_iam_policy" "allow_session_for_sisa_vapt" {
     name      = "sisa-vapt-test"
     path      = "/"
     policy    = jsonencode(
         {
             Statement = [
                 {
                     Action   = [
                         "kms:GenerateDataKey",
                         "ssm:StartSession",
                     ]
                     Effect   = "Allow"
                     Resource = [
                         "${aws_kms_key.ec2_session_key.arn}",
                         "${module.ipt_kali.arn}",
                         "${module.apppt_windows.arn}"
                     ]
                     Sid      = "VisualEditor0"
                 },
                 {
                  Effect = "Allow",
                  Action = "ssm:StartSession",
                  Resource = "arn:aws:ssm:ap-south-1::document/AWS-StartPortForwardingSession"
                 },
                 {
                     Action   = [
                         "ssm:GetConnectionStatus",
                         "ssm:DescribeInstanceInformation",
                     ]
                     Effect   = "Allow"
                     Resource = "*"
                 },

                 {
                     Action   = [
                         "ssm:ResumeSession",
                         "ssm:TerminateSession",
                     ]
                     Effect   = "Allow"
                     Resource = "arn:aws:ssm:*:*:session/sisa-*"
                     Sid      = "VisualEditor1"
                 },
                  {
                      Effect = "Allow",
                      Action = [
                          "ec2:DescribeInstances",
                          "ec2:DescribeTags",
                          "ec2:DescribeSecurityGroups",
                          "ec2:DescribeKeyPairs",
                          "ec2:DescribeVolumes"
                      ],
                      Resource = "*"
                  }
             ]
             Version   = "2012-10-17"
         }
     )
 }

 # aws_iam_user.sisa_vapt_user:
 resource "aws_iam_user" "sisa_vapt_user" {
     name      = "sisa"
     path      = "/"
 }

 # aws_iam_user_policy_attachment.allow_kali_linux_for_sisa_vapt:
 resource "aws_iam_user_policy_attachment" "allow_kali_linux_for_sisa_vapt" {
     policy_arn = aws_iam_policy.allow_session_for_sisa_vapt.arn
     user       = aws_iam_user.sisa_vapt_user.name
 }