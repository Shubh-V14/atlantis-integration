resource "aws_s3_bucket" "ups_uat_velero" {
    bucket                      = "ups-uat-velero"
    object_lock_enabled         = false

    tags = merge(local.tags,tomap({"Name" = "ups-uat-velero"}))

}

resource "aws_s3_bucket_versioning" "ups_uat_velero" {
  bucket = aws_s3_bucket.ups_uat_velero.id
  versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_kms_key" "uat_velero_storage_key" {
  description             = "Key for encrypting velero storage s3"
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

    tags = merge(local.tags,tomap({"Name" = "velero-storage"}))
}

output "uat_velero_storage_key_arn" {
  value = aws_kms_key.uat_velero_storage_key.arn
}

resource "aws_kms_alias" "uat_velero_storage_key_alias" {
  name          = "alias/uat_velero_storage"
  target_key_id = aws_kms_key.uat_velero_storage_key.id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "uat_velero_storage" {
    bucket = aws_s3_bucket.ups_uat_velero.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.uat_velero_storage_key.arn
        }
    }
    depends_on = [
        aws_kms_key.uat_velero_storage_key
    ]
}



# aws_iam_policy.ups_uat_velero_policy:
resource "aws_iam_policy" "ups_uat_velero_policy" {
    description = "ups_uat_velero s3 permissions"
    name        = "ups-uat-velero-s3-permissions"
    policy      = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload",
        "s3:DeleteObject"
      ],
      "Resource": [
        "${aws_s3_bucket.ups_uat_velero.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.ups_uat_velero.arn}"
      ]
    },
        {
            "Effect": "Allow",
            "Action": [
               "kms:GenerateDataKey",
               "kms:Decrypt"

            ],
            "Resource": [
                "${aws_kms_key.uat_velero_storage_key.arn}"
            ]
        }
  ]
}
EOT

  tags = merge(local.tags,tomap({"Name" = "ups-uat-velero-policy"}))
}


locals {
    ups_uat_velero_namespace = "velero"
    ups_uat_velero_serviceaccount = "velero-server"
}

# aws_iam_role.ups_uat_velero_role:
resource "aws_iam_role" "ups_uat_velero_role" {
    assume_role_policy    = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${var.account_id}:oidc-provider/${local.oidc_provider_url}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${local.oidc_provider_url}:aud": "sts.amazonaws.com",
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_uat_velero_namespace}:${local.ups_uat_velero_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups_uat_velero-s3-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_uat_velero_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-uat-velero-s3-role"
    path                  = "/"
    tags = merge(local.tags,tomap({"Name" = "ups-uat-velero-role"}))

}

output "ups_uat_velero_s3_role_arn" {
    value = aws_iam_role.ups_uat_velero_role.arn
}

resource "aws_s3_bucket_lifecycle_configuration" "expire" {
  rule {
    id      = "expire"
    status  = "Enabled"

    expiration {
      days = "180"
    }
  }

  bucket = aws_s3_bucket.ups_uat_velero.id
}