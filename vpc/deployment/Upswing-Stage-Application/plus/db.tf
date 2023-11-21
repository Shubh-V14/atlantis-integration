module "rds_kms_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.5"

  description = "Customer managed key to encrypt RDS"

  # Policy
  key_administrators = [
    "arn:aws:iam::${var.account_id}:root"
  ]

  # Aliases
  aliases = ["rds"]

  tags = local.tags
}

resource "aws_security_group" "db_sg1" {
    description = "Communication between db instances and rest of the stage Infrastructure 1"
    name = "db-infra1-sg"
    ingress     = [
        {
            cidr_blocks      = local.subnet_cidrs_for_nodegroup1
            description      = "allow db port from infra1 nodegroup private subnets"
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 5432
        },
    ]
    tags = {
      Name = "${local.variant}-db-sg1"
      Environment = "${local.variant}"
      Terraform = "true"
    }
    tags_all    = {}
    vpc_id      = local.db_infra1_vpc_id
    timeouts {}
}

resource "aws_db_subnet_group" "db_infra1" {
  name       = "main"
  subnet_ids = local.subnet_ids_for_db_infra1_subnets

  tags = {
    Name = "db infra 1 subnet group"
  }
}