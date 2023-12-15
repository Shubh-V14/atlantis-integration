
resource "aws_security_group" "uat_db_sg1" {
    description = "Communication between db instances and rest of the uat Infrastructure"
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
                local.uat_app_k8s_private1_cidr,
                local.uat_app_k8s_private2_cidr
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
    tags = merge(local.tags,tomap({"Name" = "uat-app-k8s-sg1"}))
    tags_all    = {}
    vpc_id      = local.uat_db1_vpc_id
    timeouts {}
}


locals {
     uat_db1_private1_id = data.terraform_remote_state.uat_infra.outputs.uat_db1_private1_id
     uat_db1_private2_id = data.terraform_remote_state.uat_infra.outputs.uat_db1_private2_id
     uat_app_k8s_private1_cidr = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private1_cidr
     uat_app_k8s_private2_cidr = data.terraform_remote_state.uat_infra.outputs.uat_app_k8s_private2_cidr
     uat_db1_vpc_id = data.terraform_remote_state.uat_infra.outputs.vpc_uat_db1_id
}

resource "aws_db_subnet_group" "db1" {
  name       = "main"
  subnet_ids = [local.uat_db1_private1_id, local.uat_db1_private2_id]


  tags = merge(local.tags,tomap({"Name" = "db1 subnet group"}))
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

    tags = merge(local.tags,tomap({"Name" = "rds_encrypt"}))
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

    tags = merge(local.tags,tomap({"Name" = "ups-infra-apps1"}))
}


# aws_db_parameter_group.ups_app_pg14:
resource "aws_db_parameter_group" "ups_app_pg14" {
    description = "ups-app-pg14"
    family      = "aurora-postgresql14"
    name        = "ups-app-pg14"

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
    tags = merge(local.tags,tomap({"Name" = "ups-app-pg14"}))
}

# aws_rds_cluster.vault1:
resource "aws_rds_cluster" "vault1" {
    availability_zones                  = [
        "ap-south-1a",
        "ap-south-1b",
        "ap-south-1c",
    ]
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "vault1"
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql14"
    db_subnet_group_name                = "main"
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
    master_password = var.password_mapping["uat_app1_password"]
    port                                = 5432
    preferred_backup_window             = "21:53-22:23"
    preferred_maintenance_window        = "sat:20:00-sat:20:30"
    skip_final_snapshot                 = true
    storage_encrypted                   = true
    vpc_security_group_ids              = [
        aws_security_group.uat_db_sg1.id,
    ]

    serverlessv2_scaling_configuration {
        max_capacity = 1
        min_capacity = 0.5
    }

    timeouts {}

    tags = merge(local.tags,tomap({"Name" = "vault1"}))
}

# aws_rds_cluster_instance.infra_app1_instance:
resource "aws_rds_cluster_instance" "vault11_instance" {
    auto_minor_version_upgrade            = true
    availability_zone                     = "ap-south-1a"
    cluster_identifier                    = aws_rds_cluster.vault1.id
    copy_tags_to_snapshot                 = true
    db_parameter_group_name               = aws_db_parameter_group.ups_pg14_vault.name
    db_subnet_group_name                  = aws_db_subnet_group.db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.6"
    instance_class                        = "db.t3.medium"
    monitoring_interval                   = 0
    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    promotion_tier                        = 1
    publicly_accessible                   = false

    timeouts {}

  tags = merge(local.tags,tomap({"Name" = "vault1-instance"}))
}


resource "aws_rds_cluster" "infra_apps1"  {
    availability_zones                  = [
        "ap-south-1a",
        "ap-south-1b",
        "ap-south-1c",
    ]
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "infra-apps1"
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql14"
    db_subnet_group_name                = "main"
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
    master_password = var.password_mapping["uat_app1_password"]
    port                                = 5432
    preferred_backup_window             = "18:19-18:49"
    preferred_maintenance_window        = "fri:07:49-fri:08:19"
    skip_final_snapshot                 = true
    storage_encrypted                   = true
    vpc_security_group_ids              = [
        aws_security_group.uat_db_sg1.id,
    ]

    serverlessv2_scaling_configuration {
        max_capacity = 2
        min_capacity = 0.5
    }

    timeouts {}

      tags = merge(local.tags,tomap({"Name" = "infra-apps1"}))
}

# aws_rds_cluster_instance.infra_app1_instance:
resource "aws_rds_cluster_instance" "infra_apps1_instance" {
    identifier = "infra-apps1-instance-1"
    auto_minor_version_upgrade            = true
    availability_zone                     = "ap-south-1a"
    cluster_identifier                    = aws_rds_cluster.infra_apps1.id
    copy_tags_to_snapshot                 = true
    db_parameter_group_name               = aws_db_parameter_group.ups_infra_apps1.name
    db_subnet_group_name                  = aws_db_subnet_group.db1.name
    engine                                = "aurora-postgresql"
    engine_version                        = "14.6"
    instance_class                        = "db.t3.medium"
    monitoring_interval                   = 0
    performance_insights_enabled          = true
    performance_insights_retention_period = 7
    promotion_tier                        = 1
    publicly_accessible                   = false

    tags = merge(local.tags,tomap({"Name" = "infra-apps1-instance"}))
    timeouts {}
}

resource "aws_kms_key" "ups_backup_encryption" {
  description             = "Key for encrypting backups at rest"
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

    tags = merge(local.tags,tomap({"Name" = "rds_backup_encrypt"}))
}

resource "aws_kms_alias" "rds_backup_key_alias" {
  name          = "alias/rds_backup_encrypt"
  target_key_id = aws_kms_key.ups_backup_encryption.id
}


variable "password_mapping" {
    type = map(string)
}
