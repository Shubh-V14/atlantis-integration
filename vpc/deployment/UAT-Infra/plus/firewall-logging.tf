resource "aws_kms_key" "firewall_logging_key" {
  description             = "Key for encrypting firewall logging s3"
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
        },
                       {
                       Action    = "kms:GenerateDataKey*"
                       Effect    = "Allow"
                       Principal = {
                          Service = "delivery.logs.amazonaws.com"
                       }
                       Resource  = "*"
                       Sid       = "Allow Network Firewall to use the key"
                    }
            ]
            Version   = "2012-10-17"
        }
    )
   tags = {
      Environment = "uat"
      Name        = "firewall-logging"
    }
}

output "firewall_logging_key_arn" {
  value = aws_kms_key.firewall_logging_key.arn
}

resource "aws_kms_alias" "firewall_logging_key_alias" {
  name          = "alias/firewall_logging"
  target_key_id = aws_kms_key.firewall_logging_key.id
}


resource "aws_s3_bucket" "firewall_logging" {
    bucket                      = "ups-firewall-logs-uat"
    object_lock_enabled         = false
    tags                        = {}
    tags_all                    = {}


}

resource "aws_s3_bucket_versioning" "firewall_logging" {
  bucket = aws_s3_bucket.firewall_logging.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firewall_logging" {
    bucket = aws_s3_bucket.firewall_logging.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.firewall_logging_key.arn
        }
    }
    depends_on = [
        aws_kms_key.firewall_logging_key
    ]
}

resource "aws_cloudwatch_log_group" "firewall_loggroup" {
  name = "firewall-loggroup"

  tags = {
    Environment = "uat"
  }
}

resource "aws_networkfirewall_logging_configuration" "firewall_logging_cfg" {
  firewall_arn = aws_networkfirewall_firewall.uat_firewall1.arn
  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_loggroup.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
     log_destination_config {
      log_destination = {
        logGroup = "firewall-flow-logs"
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
