locals {
    prod_noncde_db_vpc_id =  data.terraform_remote_state.prod_infra.outputs.vpc_prod_noncde_db_infra_id
    prod_noncde_db_private1_id =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_db_private1_id
    prod_noncde_db_private2_id =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_db_private2_id
    prod_noncde_private1_cidr =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private1_cidr
    prod_noncde_private2_cidr =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private2_cidr
    prod_noncde_private3_cidr =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private3_cidr
    prod_noncde_private4_cidr =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private4_cidr
    prod_noncde_private5_cidr =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private5_cidr
    prod_noncde_private6_cidr =  data.terraform_remote_state.prod_infra.outputs.prod_noncde_private6_cidr

}
resource "aws_security_group" "prod_db_sg1" {
    description = "Communication between db instances and rest of the prod Infrastructure"
    egress      = [
        {
            cidr_blocks      = [
                local.prod_noncde_private1_cidr,
                local.prod_noncde_private2_cidr
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
                local.prod_noncde_private1_cidr,
                local.prod_noncde_private2_cidr,
                local.prod_noncde_private3_cidr,
                local.prod_noncde_private4_cidr,
                local.prod_noncde_private5_cidr,
                local.prod_noncde_private6_cidr
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
      Name = "prod-noncde-db-sg1"
      Environment = "prod"
      Terraform = "true"
    }
    tags_all    = {}
    vpc_id      = local.prod_noncde_db_vpc_id
    timeouts {}
}


# locals {
#      prod_db1_private1_id = 1
#      prod_db1_private2_id = 1
#      prod_app_k8s_private1_cidr = "0.0.0.0/0"
#      prod_app_k8s_private2_cidr = "0.0.0.0/0"
#      prod_db1_vpc_id = "0.0.0.0/0"
# }
resource "aws_db_subnet_group" "db1" {
  name       = "noncde1"
  subnet_ids = [local.prod_noncde_db_private1_id, local.prod_noncde_db_private2_id]

  tags = {
    Name = "db1 subnet group"
  }
}

resource "aws_kms_key" "ups_rds" {
  description             = "Key for encrypting rds data at rest"
  deletion_window_in_days = 10
  key_usage = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
  policy                   = jsonencode(
        {
            Statement = [
      {
        "Sid"= "Allow current account to administer the key"
        "Effect"= "Allow",
         "Principal"= {
        "AWS"= "arn:aws:iam::${var.account_id}:root"
        },
        "Action"= "kms:*",
        "Resource"= "*"
        }
            ]
            Version   = "2012-10-17"
        }
    )
   tags = {
      Environment = "prod"
      Name        = "rds_encrypt"
    }
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/rds_encrypt"
  target_key_id = aws_kms_key.ups_rds.id
}

# aws_db_parameter_group.ups_pg14_vault:
resource "aws_db_parameter_group" "ups_pg14_vault" {
    description = "ups-pg14-vault"
    family      = "aurora-postgresql14"
    name        = "ups-pg14-vault"
    tags        = {}
    tags_all    = {}

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
}

resource "aws_db_parameter_group" "ups_infra_apps1" {
    description = "ups-infra-apps1"
    family      = "aurora-postgresql14"
    name        = "ups-infra-apps1"
    tags        = {}
    tags_all    = {}

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
}


# aws_db_parameter_group.ups_app_pg14:
resource "aws_db_parameter_group" "ups_app_pg14" {
    description = "ups-app-pg14"
    family      = "aurora-postgresql14"
    name        = "ups-app-pg14"
    tags        = {}
    tags_all    = {}

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

    parameter {
        apply_method = "pending-reboot"
        name         = "max_connections"
        value        = "3000"
    }
}

# aws_rds_cluster.vault1:
resource "aws_rds_cluster" "vault1" {
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "noncde-vault"
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql14"
    db_subnet_group_name                = aws_db_subnet_group.db1.name
    deletion_protection                 = true
    enable_http_endpoint                = false
    enabled_cloudwatch_logs_exports     = [
        "postgresql",
    ]
    engine                              = "aurora-postgresql"
    engine_mode                         = "provisioned"
    engine_version                      = "14.3"
    iam_database_authentication_enabled = true
    iam_roles                           = []
    kms_key_id                          =  "${aws_kms_key.ups_rds.arn}"
    master_username                     = "postgres"
    master_password                     = "${var.vault1_pass}"
    port                                = 5432
    preferred_backup_window             = "21:53-22:23"
    preferred_maintenance_window        = "sat:20:00-sat:20:30"
    skip_final_snapshot                 = true
    storage_encrypted                   = true
    tags                                = {}
    tags_all                            = {}
    vpc_security_group_ids              = [
        aws_security_group.prod_db_sg1.id,
    ]

    lifecycle {
        ignore_changes = [master_password]
    }

    timeouts {}
}

resource "aws_rds_cluster_instance" "vault1_instances" {
    identifier = "vault1"
    auto_minor_version_upgrade            = false
    availability_zone                     = "ap-south-1c"
    cluster_identifier                    = aws_rds_cluster.vault1.id
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = aws_db_parameter_group.ups_pg14_vault.name
    db_subnet_group_name                  = aws_db_subnet_group.db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.3"
    instance_class                        = "db.t3.medium"
    monitoring_interval                   = 0
    performance_insights_enabled          = false
    promotion_tier                        = 1
    publicly_accessible                   = false
    tags                                  = {}
    tags_all                              = {}



    timeouts {}
}

resource "aws_rds_cluster" "prod_app1"  {
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "prod-app1"
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql14"
    db_subnet_group_name                = aws_db_subnet_group.db1.name
    deletion_protection                 = true
    enable_http_endpoint                = false
    enabled_cloudwatch_logs_exports     = [
        "postgresql",
    ]
    engine                              = "aurora-postgresql"
    engine_mode                         = "provisioned"
    engine_version                      = "14.5"
    iam_database_authentication_enabled = true
    iam_roles                           = []
    kms_key_id                          =  "${aws_kms_key.ups_rds.arn}"
    master_username                     = "postgres"
    master_password                     = "${var.prod_app1_pass}"
    port                                = 5432
    preferred_backup_window             = "23:10-23:40"
    preferred_maintenance_window        = "sat:20:00-sat:20:30"
    skip_final_snapshot                 = true
    storage_encrypted                   = true
    tags                                = {}
    tags_all                            = {}
    vpc_security_group_ids              = [
        aws_security_group.prod_db_sg1.id,
    ]

  lifecycle {
        ignore_changes = [master_password]
    }
  

    timeouts {}
}

# aws_rds_cluster_instance.prod_app1_instance:
resource "aws_rds_cluster_instance" "prod_app1_instance" {
    auto_minor_version_upgrade            = true
    availability_zone                     = "ap-south-1a"
    cluster_identifier                    = aws_rds_cluster.prod_app1.id
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = aws_db_parameter_group.ups_app_pg14.name
    db_subnet_group_name                  = aws_db_subnet_group.db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.5"
    instance_class                        = "db.r6g.large"
    monitoring_interval                   = 0
    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    promotion_tier                        = 1
    publicly_accessible                   = false
    tags                                  = {}
    tags_all                              = {}

    timeouts {}
}

# aws_rds_cluster_instance.prod_app1_instance:
resource "aws_rds_cluster_instance" "prod_app1_instance2" {
    auto_minor_version_upgrade            = true
    availability_zone                     = "ap-south-1c"
    cluster_identifier                    = aws_rds_cluster.prod_app1.id
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = aws_db_parameter_group.ups_app_pg14.name
    db_subnet_group_name                  = aws_db_subnet_group.db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.5"
    identifier                            = "prod-app1-reader1"
    instance_class                        = "db.r6g.large"
    monitoring_interval                   = 0
    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    publicly_accessible                   = false
    tags                                  = {}
    tags_all                              = {}
    promotion_tier                        = 1
    timeouts {}
}

resource "aws_rds_cluster" "infra_apps1"  {
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "infra-apps1"
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql14"
    db_subnet_group_name                = aws_db_subnet_group.db1.name
    deletion_protection                 = true
    enable_http_endpoint                = false
    enabled_cloudwatch_logs_exports     = [
        "postgresql",
    ]
    engine                              = "aurora-postgresql"
    engine_mode                         = "provisioned"
    engine_version                      = "14.5"
    iam_database_authentication_enabled = true
    iam_roles                           = []
    kms_key_id                          = "${aws_kms_key.ups_rds.arn}"
    master_username                     = "postgres"
    master_password                     = "${var.infra_apps1_pass}"
    port                                = 5432
    preferred_backup_window             = "18:19-18:49"
    preferred_maintenance_window        = "fri:07:49-fri:08:19"
    skip_final_snapshot                 = true
    storage_encrypted                   = true
    tags                                = {}
    tags_all                            = {}
    vpc_security_group_ids              = [
        aws_security_group.prod_db_sg1.id,
    ]
      lifecycle {
        ignore_changes = [master_password]
    }

    timeouts {}
}

# aws_rds_cluster_instance.infra_app1_instance:
resource "aws_rds_cluster_instance" "infra_app1_instance" {
    auto_minor_version_upgrade            = true
    availability_zone                     = "ap-south-1a"
    cluster_identifier                    = aws_rds_cluster.infra_apps1.id
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = aws_db_parameter_group.ups_infra_apps1.name
    db_subnet_group_name                  = aws_db_subnet_group.db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.5"
    instance_class                        = "db.t3.medium"
    monitoring_interval                   = 0
    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    promotion_tier                        = 1
    publicly_accessible                   = false
    tags                                  = {}
    tags_all                              = {}

    timeouts {}
}

