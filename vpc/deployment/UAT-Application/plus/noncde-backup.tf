resource "aws_backup_vault" "noncde_backup_vault" {
    kms_key_arn     = aws_kms_key.ups_backup_encryption.arn
    name            = "noncde-app1"
    tags            = {}
    tags_all        = {}

    timeouts {}
}

resource "aws_backup_plan" "noncde_backup_plan" {
    name     = "noncde-app1"
    tags     = {}
    tags_all = {}

    rule {
        completion_window        = 180
        enable_continuous_backup = false
        recovery_point_tags      = {}
        rule_name                = "weekly_backup"
        schedule                 = "cron(0 21 ? * 1 *)"
        start_window             = 60
        target_vault_name        = "noncde-app1"

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
        target_vault_name        = "noncde-app1"

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
        target_vault_name        = "noncde-app1"

        lifecycle {
            cold_storage_after = 0
            delete_after       = 8
        }
    }
}

resource "aws_backup_selection" "noncde_rds_selection" {
    iam_role_arn  = "arn:aws:iam::199381154999:role/service-role/AWSBackupDefaultServiceRole"
    name          = "noncde-app-assigment"
    not_resources = []
    plan_id       = aws_backup_plan.noncde_backup_plan.id
    resources     = [
        aws_rds_cluster.uat_noncde_app1.arn
    ]

    condition {
    }

}