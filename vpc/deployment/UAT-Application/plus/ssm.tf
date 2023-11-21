resource "aws_s3_bucket" "ups_uat_ssm" {
    bucket                      = "ups-uat-ssm"
    object_lock_enabled         = false

    tags = merge(local.tags,tomap({"Name" = "ups-uat-ssm"}))

}

resource "aws_s3_bucket_versioning" "ups_uat_ssm" {
  bucket = aws_s3_bucket.ups_uat_ssm.id
  versioning_configuration {
        status = "Suspended"
    }
}

resource "aws_kms_key" "uat_ssm_storage_key" {
  description             = "Key for encrypting ssm storage s3"
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

    tags = merge(local.tags,tomap({"Name" = "ssm-storage"}))
}

output "uat_ssm_storage_key_arn" {
  value = aws_kms_key.uat_ssm_storage_key.arn
}

resource "aws_kms_alias" "uat_ssm_storage_key_alias" {
  name          = "alias/uat_ssm_storage"
  target_key_id = aws_kms_key.uat_ssm_storage_key.id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "uat_ssm_storage" {
    bucket = aws_s3_bucket.ups_uat_ssm.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.uat_ssm_storage_key.arn
        }
    }
    depends_on = [
        aws_kms_key.uat_ssm_storage_key
    ]
}

