resource "aws_kms_key" "ups_idp_state_key" {
  description             = "Key for encrypting ups-idp-state s3"
  deletion_window_in_days = 10
  key_usage = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
  policy                   = jsonencode(
        {
            Statement = [
                {
        "Sid"= "Allow use of the key for all the accounts in the organization",
        "Effect"= "Allow",
         "Principal"= {
        "AWS"= sort(["arn:aws:iam::199381154999:role/tf-ws", "${aws_iam_role.tf_idp_state_manager_role.arn}"])
        },
        "Action"= [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
    ],
        "Resource"= "*"
    },
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

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ups-idp-state-key"}))
}

output "ups_idp_state_key_arn" {
  value = aws_kms_key.ups_idp_state_key.arn
}

resource "aws_kms_alias" "ups_idp_state_key_alias" {
  name          = "alias/ups_idp_state"
  target_key_id = aws_kms_key.ups_idp_state_key.id
}


resource "aws_s3_bucket" "ups_idp_state" {
    bucket                      = "ups-idp-state"
    object_lock_enabled         = false


    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "ups-idp-state"}))

}

resource "aws_s3_bucket_versioning" "ups-idp-state" {
  bucket = aws_s3_bucket.ups_idp_state.id
  versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_lifecycle_configuration" "keep_10_versions_for_idp_state_bucket" {
    bucket = aws_s3_bucket.ups_idp_state.id

    rule {
        id     = "keep-10-versions"
        status = "Enabled"

        filter {
        }

        noncurrent_version_expiration {
            newer_noncurrent_versions = "10"
            noncurrent_days           = 7
        }
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ups-idp-state" {
    bucket = aws_s3_bucket.ups_idp_state.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.ups_idp_state_key.arn
        }
    }
    depends_on = [
        aws_kms_key.ups_idp_state_key
    ]
}


resource "aws_s3_bucket_policy" "ups_idp_state_policy" {
    bucket = aws_s3_bucket.ups_idp_state.id
    policy = jsonencode(
      {
      "Version" = "2012-10-17",
      "Statement" = [
          {
      "Effect" = "Allow",
      "Action" = "s3:ListBucket"
      "Resource" = "${aws_s3_bucket.ups_idp_state.arn}",
      "Principal" = {
        "AWS" = "${["arn:aws:iam::199381154999:role/tf-ws", aws_iam_role.tf_idp_state_manager_role.arn]}"
      }
      },
      {
        "Effect" = "Allow",
        "Action" = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        "Resource" = [
        "${aws_s3_bucket.ups_idp_state.arn}/*",
        "${aws_s3_bucket.ups_idp_state.arn}"
        ]
      "Principal" = {
        "AWS" = "${["arn:aws:iam::199381154999:role/tf-ws", aws_iam_role.tf_idp_state_manager_role.arn]}"
      }
      }

      ]
      }
    )
}

resource "aws_dynamodb_table" "ups_idp_state" {
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "LockID"
  name             = "ups-idp-state-lock-table"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
    kms_key_arn = aws_kms_key.ups_idp_state_key.arn
  }


  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "TF State locking"}))
}

resource "aws_iam_policy" "ups_idp_state_table_policy" {
    description = "ups-idp-state-table-policy"
    name = "ups-idp-state-table-policy"
    policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/${aws_dynamodb_table.ups_idp_state.name}"
    }
  ]
}
EOT
    tags        = {}
    tags_all    = {}
}

resource "aws_iam_policy" "ups_idp_state_kms_policy" {
    description = "ups-idp-state-kms-policy"
    name = "ups-idp-state-kms-policy"
    policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
        {
   "Effect": "Allow",
   "Action": [
       "kms:Encrypt",
       "kms:Decrypt",
       "kms:ReEncrypt*",
       "kms:GenerateDataKey*",
       "kms:DescribeKey",
       "kms:CreateGrant" 

   ],
   "Resource": "${aws_kms_key.ups_idp_state_key.arn}"
},
     {
      "Effect": "Allow",
      "Action": [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
      ],
      "Resource": [
        "${aws_s3_bucket.ups_idp_state.arn}",
        "${aws_s3_bucket.ups_idp_state.arn}/*"
      ]
    }
  ]
}
EOT
    tags        = {}
    tags_all    = {}
}


# aws_iam_role.role_route53_role:
resource "aws_iam_role" "tf_idp_state_manager_role" {
    description           = "tf-idp-state-manager"
    force_detach_policies = false
    assume_role_policy = jsonencode({
  "Version" = "2012-10-17",
  "Statement"= [
    {
      "Effect"= "Allow",
      "Principal"= {
        "AWS"= concat(sort(jsondecode(var.org_arns)),["arn:aws:iam::199381154999:role/tf-ws"])
      },
      "Action"="sts:AssumeRole"
    }
  ]
})
    max_session_duration  = 3600
    name                  = "tf-idp-state-manager"
    path                  = "/"
    tags                  = {}
    tags_all              = {}

}

output "tf_idp_state_manager_role_arn" {
    value = aws_iam_role.tf_idp_state_manager_role.arn
}

locals {
  idp_state_manager_policies = [aws_iam_policy.ups_idp_state_kms_policy.arn, aws_iam_policy.ups_idp_state_table_policy.arn]
}
resource aws_iam_role_policy_attachment "attach_idp_state_policies_to_state_manager" {
    count  = length(local.idp_state_manager_policies)
    role = aws_iam_role.tf_idp_state_manager_role.name
    policy_arn = local.idp_state_manager_policies[count.index]
}