
resource "aws_security_group" "stage_db_sg1" {
    description = "Communication between db instances and rest of the stage Infrastructure"
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
            cidr_blocks      = [
                local.stage_app_k8s_private1_cidr,
                local.stage_app_k8s_private2_cidr
            ]
            description      = "allow db port from k8s private subnets"
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
      Name = "stage-app-k8s-sg1"
      Environment = "stage"
      Terraform = "true"
    }
    tags_all    = {}
    vpc_id      = local.stage_db1_vpc_id
    timeouts {}
}


locals {
     stage_db1_private1_id = data.terraform_remote_state.stage_infra.outputs.stage_db1_private1_id
     stage_db1_private2_id = data.terraform_remote_state.stage_infra.outputs.stage_db1_private2_id
}
resource "aws_db_subnet_group" "db1" {
  name       = "main"
  subnet_ids = [local.stage_db1_private1_id, local.stage_db1_private2_id]

  tags = {
    Name = "db1 subnet group"
  }
}