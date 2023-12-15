
locals {
     uat_cde_db1_vpc_id = data.terraform_remote_state.uat_infra.outputs.vpc_uat_db1_id
     uat_cde_db1_private1_id = data.terraform_remote_state.uat_infra.outputs.uat_cde_db1_private1_id
     uat_cde_db1_private2_id = data.terraform_remote_state.uat_infra.outputs.uat_cde_db1_private2_id
     uat_cde_private1_cidr = data.terraform_remote_state.uat_infra.outputs.uat_cde_private1_cidr
     uat_cde_private2_cidr = data.terraform_remote_state.uat_infra.outputs.uat_cde_private2_cidr
}

resource "aws_security_group" "uat_cde_db_sg1" {
    description = "Communication between cde db instances and cde app infra"
    ingress     = [
        {
            cidr_blocks      = [
                local.uat_cde_private1_cidr,
                local.uat_cde_private2_cidr,
                local.uat_app_k8s_private1_cidr,
                local.uat_app_k8s_private2_cidr
            ]
            description      = "allow db port from uat cde private subnets"
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 5432
        },
    ]
    tags = merge(local.tags,tomap({"Name" = "uat-cde-db-sg1"}))
    tags_all    = {}
    vpc_id      = local.uat_db1_vpc_id
    timeouts {}
}

resource "aws_db_subnet_group" "cde-db1" {
  name       = "cde"
  subnet_ids = [local.uat_cde_db1_private1_id, local.uat_cde_db1_private2_id]


  tags = merge(local.tags,tomap({"Name" = "cde db1 subnet group"}))
}

# aws_db_parameter_group.ups_app_pg14:
resource "aws_db_parameter_group" "ups_cde_db1_pg14" {
    description = "ups-cde-db1-pg14"
    family      = "aurora-postgresql14"
    name        = "ups-cde-db1-pg14"

    parameter {
        apply_method = "immediate"
        name         = "log_duration"
        value        = "1"
    }
    parameter {
        apply_method = "immediate"
        name         = "log_min_duration_statement"
        value        = "0"
    }
    parameter {
        apply_method = "immediate"
        name         = "log_statement"
        value        = "all"
    }
    tags = merge(local.tags,tomap({"Name" = "ups-cde-db1-pg14"}))
}


resource "aws_rds_cluster" "uat_cde_app1"  {
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "uat-cde-app1"
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql14"
    db_subnet_group_name                = "cde"
    deletion_protection                 = true
    enable_http_endpoint                = false
    enabled_cloudwatch_logs_exports     = [
        "postgresql",
    ]
    engine                              = "aurora-postgresql"
    engine_mode                         = "provisioned"
    engine_version                      = "14.6"
    iam_database_authentication_enabled = true
    iam_roles                           = []
    kms_key_id                          = "${aws_kms_key.ups_rds.arn}"
    master_username                     = "postgres"
    master_password = var.password_mapping["uat_cde_app1_password"]
    port                                = 5432
    preferred_backup_window             = "23:10-23:40"
    preferred_maintenance_window        = "sat:20:00-sat:20:30"
    skip_final_snapshot                 = true
    storage_encrypted                   = true
    vpc_security_group_ids              = [
        aws_security_group.uat_cde_db_sg1.id
    ]

    serverlessv2_scaling_configuration {
        max_capacity = 4
        min_capacity = 0.5
    }

    timeouts {}

    tags = merge(local.tags,tomap({"Name" = "uat-cde-app1"}))
}

# aws_rds_cluster_instance.infra_app1_instance:
resource "aws_rds_cluster_instance" "uat_cde_app1_instance" {
    identifier = "uat-cde-app1-instance-1"
    auto_minor_version_upgrade            = true
    cluster_identifier                    = aws_rds_cluster.uat_cde_app1.id
    copy_tags_to_snapshot                 = true
    db_parameter_group_name               = aws_db_parameter_group.ups_cde_db1_pg14.name
    db_subnet_group_name                  = aws_db_subnet_group.cde-db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.6"
    instance_class                        = "db.t3.medium"
    monitoring_interval                   = 0
    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    promotion_tier                        = 1
    publicly_accessible                   = false
    tags = merge(local.tags,tomap({"Name" = "uat-cde-app1-instance"}))

    timeouts {}
}
