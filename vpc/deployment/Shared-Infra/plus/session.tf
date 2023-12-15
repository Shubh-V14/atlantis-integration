resource "aws_kms_key" "ec2_session_key" {
  description = "Key for encrypting ec2 session"
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

    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ec2-session-key"}))
}

output "ec2_session_key_arn" {
  value = aws_kms_key.ec2_session_key.arn
}

resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/ec2_session_key"
  target_key_id = aws_kms_key.ec2_session_key.key_id
}


resource "aws_s3_bucket" "ups_prod_ec2_session" {
    bucket                      = "ups-prod-ec2-session"
    object_lock_enabled         = false


    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ups-prod-ec2-session"}))

}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod_ec2_session_storage" {
    bucket = aws_s3_bucket.ups_prod_ec2_session.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.ec2_session_key.arn
        }
    }
    depends_on = [
        aws_kms_key.ec2_session_key
    ]
}