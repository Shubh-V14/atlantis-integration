resource "aws_backup_vault" "cde_backup_vault" {
    kms_key_arn     = aws_kms_key.ups_backup_encryption.arn
    name            = "cde-app1"
    tags            = {}
    tags_all        = {}

    timeouts {}
}

resource "aws_backup_plan" "cde_backup_plan" {
    name     = "cde-app1"
    tags     = {}
    tags_all = {}

    rule {
        completion_window        = 180
        enable_continuous_backup = false
        recovery_point_tags      = {}
        rule_name                = "weekly_backup"
        schedule                 = "cron(0 21 ? * 1 *)"
        start_window             = 60
        target_vault_name        = "cde-app1"

        lifecycle {
            cold_storage_after = 0
            delete_after       = 35
        }
    }
    rule {
        completion_window        = 180
        enable_continuous_backup = false
        recovery_point_tags      = {}
        rule_name                = "monthly_backup_plan"
        schedule                 = "cron(0 23 1 * ? *)"
        start_window             = 60
        target_vault_name        = "cde-app1"

        lifecycle {
            cold_storage_after = 0
            delete_after       = 3650
        }
    }
    rule {
        completion_window        = 180
        enable_continuous_backup = false
        recovery_point_tags      = {}
        rule_name                = "daily_backup"
        schedule                 = "cron(0 20 ? * * *)"
        start_window             = 60
        target_vault_name        = "cde-app1"

        lifecycle {
            cold_storage_after = 0
            delete_after       = 8
        }
    }
}

resource "aws_backup_selection" "cde_rds_selection" {
    iam_role_arn  = "arn:aws:iam::199381154999:role/service-role/AWSBackupDefaultServiceRole"
    name          = "cde-app-assigment"
    not_resources = []
    plan_id       = aws_backup_plan.cde_backup_plan.id
    resources     = [
        aws_rds_cluster.uat_cde_app1.arn
    ]

    condition {
    }

}