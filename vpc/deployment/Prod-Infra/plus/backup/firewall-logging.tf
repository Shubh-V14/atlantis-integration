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
        }
            ]
            Version   = "2012-10-17"
        }
    )
   tags = {
      Environment = "Prod"
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
    bucket                      = "ups-firewall-logs"
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
    Environment = "Prod"
  }
}

resource "aws_networkfirewall_logging_configuration" "firewall_logging_cfg" {
  firewall_arn = aws_networkfirewall_firewall.prod_firewall1.arn
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
        bucketName = aws_s3_bucket.firewall_logging.bucket
        prefix     = "flow"
      }
      log_destination_type = "S3"
      log_type             = "FLOW"
    }
  }
}
