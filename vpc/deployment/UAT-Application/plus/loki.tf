resource "aws_s3_bucket" "ups_uat_loki" {
    bucket                      = "ups-uat-loki"
    object_lock_enabled         = false

    tags = merge(local.tags,tomap({"Name" = "ups-uat-loki"}))

}

resource "aws_s3_bucket_versioning" "ups_uat_loki" {
  bucket = aws_s3_bucket.ups_uat_loki.id
  versioning_configuration {
        status = "Enabled"
    }
}

resource "aws_kms_key" "uat_loki_storage_key" {
  description             = "Key for encrypting loki storage s3"
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

    tags = merge(local.tags,tomap({"Name" = "loki-storage"}))
}

output "uat_loki_storage_key_arn" {
  value = aws_kms_key.uat_loki_storage_key.arn
}

resource "aws_kms_alias" "uat_loki_storage_key_alias" {
  name          = "alias/uat_loki_storage"
  target_key_id = aws_kms_key.uat_loki_storage_key.id
}



resource "aws_s3_bucket_server_side_encryption_configuration" "uat_loki_storage" {
    bucket = aws_s3_bucket.ups_uat_loki.id
    rule {
        bucket_key_enabled = false

        apply_server_side_encryption_by_default {
            sse_algorithm = "aws:kms"
            kms_master_key_id = aws_kms_key.uat_loki_storage_key.arn
        }
    }
    depends_on = [
        aws_kms_key.uat_loki_storage_key
    ]
}



# aws_iam_policy.ups_uat_loki_policy:
resource "aws_iam_policy" "ups_uat_loki_policy" {
    description = "ups_uat_loki s3 permissions"
    name        = "ups-uat-loki-s3-permissions"
    policy      = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListObjects"
            ],
            "Resource": [
                "arn:aws:s3:::ups-uat-loki/*",
                "arn:aws:s3:::ups-uat-loki"
            ]
        },
                {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
               "kms:GenerateDataKey",
               "kms:Decrypt"

            ],
            "Resource": [
                "${aws_kms_key.uat_loki_storage_key.arn}"
            ]
        }

    ]
}
EOT

  tags = merge(local.tags,tomap({"Name" = "ups-uat-loki-policy"}))
}


locals {
    ups_uat_loki_namespace = "loki"
    ups_uat_loki_serviceaccount = "loki"
}

# aws_iam_role.ups_uat_loki_role:
resource "aws_iam_role" "ups_uat_loki_role" {
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
          "${local.oidc_provider_url}:sub": "system:serviceaccount:${local.ups_uat_loki_namespace}:${local.ups_uat_loki_serviceaccount}"
        }
      }
    }
  ]
}
EOT
    description           = "ups_uat_loki-s3-role"
    force_detach_policies = false

    managed_policy_arns   = [
        "${aws_iam_policy.ups_uat_loki_policy.arn}"
    ]
    max_session_duration  = 3600
    name                  = "ups-uat-loki-s3-role"
    path                  = "/"
    tags = merge(local.tags,tomap({"Name" = "ups-uat-loki-role"}))

}

output "ups_uat_loki_s3_role_arn" {
    value = aws_iam_role.ups_uat_loki_role.arn
}

resource "aws_sns_topic" "s3_event_forwarder" {
  name = "s3-event-notification-topic"

  policy = <<POLICY
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:s3-event-notification-topic",
        "Condition":{
            "ArnLike":{
                "aws:SourceArn":[
                "${aws_s3_bucket.ups_uat_loki.arn}"
                ]
            }
        }
    }]
}
POLICY
}


resource "aws_sns_topic_subscription" "subscribe_to_loki_bucket_deletion" {
  topic_arn = aws_sns_topic.s3_event_forwarder.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.s3_event_forwarder.arn
}

# If skipping this resource configuration, also add "logs:CreateLogGroup" to the IAM policy below.
resource "aws_cloudwatch_log_group" "s3_event_forwarder" {
  name              = "/aws/lambda/s3_event_forwarder"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
        {
            "Action": [
                "sns:publish"
            ],
            "Resource": "arn:aws:sns:*:133459798589:aws-controltower-AggregateSecurityNotifications",
            "Effect": "Allow"
        }
  ]
}
EOF
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "s3_event_forwarder" {
    description                    = "SNS message forwarding function for aggregating account notifications."
    function_name                  = "s3_event_forwarder"
    handler                        = "index.lambda_handler"
    memory_size                    = 128
    package_type                   = "Zip"
    role                           = aws_iam_role.iam_for_lambda.arn
    runtime                        = "python3.9"
    source_code_hash               = filebase64sha256("s3_event_forwarder/s3_event_forwarder.zip")
    filename =                      "s3_event_forwarder/s3_event_forwarder.zip"
    tags                           = {}
    tags_all                       = {}
    timeout                        = 60

    environment {
        variables = {
            "sns_arn" = "arn:aws:sns:ap-south-1:133459798589:aws-controltower-AggregateSecurityNotifications"
        }
    }

    ephemeral_storage {
        size = 512
    }

    timeouts {}

    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_permission" "allow_sns" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.s3_event_forwarder.function_name
    principal     = "sns.amazonaws.com"
    source_arn    = aws_sns_topic.s3_event_forwarder.arn
    statement_id  = "allow"
}



#####S3-FIM-forwarder


# If skipping this resource configuration, also add "logs:CreateLogGroup" to the IAM policy below.
resource "aws_cloudwatch_log_group" "s3_fim_forwarder" {
  name              = "/aws/lambda/s3_fim_forwarder"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "s3_fim_lambda_permissions" {
  name        = "s3_fim_lambda_permissions"
  path        = "/"
  description = "IAM policy for s3 fim lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:GetLifecycleConfiguration"
        ],
        "Resource": [
        "${aws_s3_bucket.ups_uat_loki.arn}",
        "${aws_s3_bucket.ups_uat_loki.arn}/*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucketVersions"
        ],
        "Resource": [
        "${aws_s3_bucket.ups_uat_loki.arn}"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ],
        "Resource": [
        "${aws_s3_bucket.ups_uat_loki.arn}/*"
        ]
    },
                    {
            "Effect": "Allow",
            "Action": [
               "kms:GenerateDataKey",
               "kms:Decrypt"

            ],
            "Resource": [
                "${aws_kms_key.uat_loki_storage_key.arn}"
            ]
        },
        {
            "Action": [
                "sns:publish"
            ],
            "Resource": "arn:aws:sns:*:133459798589:aws-controltower-AggregateSecurityNotifications",
            "Effect": "Allow"
        }
  ]
}
EOF
}

resource "aws_iam_role" "s3_fim_lambda_role" {
  name = "s3_fim_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_fim_lambda" {
  role       = aws_iam_role.s3_fim_lambda_role.name
  policy_arn = aws_iam_policy.s3_fim_lambda_permissions.arn
}

data "archive_file" "s3_fim_forwarder_archive" {
    type = "zip"
    output_path = "s3_fim_forwarder.zip"
    source_dir = "s3_fim_forwarder"
}

resource "aws_lambda_function" "s3_fim_forwarder" {
    depends_on = [
      data.archive_file.s3_fim_forwarder_archive
    ]
    description                    = "SNS message processor and forwarder for s3 fim events"
    function_name                  = "s3_fim_forwarder"
    handler                        = "app.handler"
    memory_size                    = 128
    package_type                   = "Zip"
    role                           = aws_iam_role.s3_fim_lambda_role.arn
    runtime                        = "nodejs14.x"
    source_code_hash               = data.archive_file.s3_fim_forwarder_archive.output_base64sha256
    filename =                      "s3_fim_forwarder.zip"
    tags                           = {}
    tags_all                       = {}
    timeout                        = 60

    environment {
        variables = {
            "SNS_NOTIFICATION_TOPIC" = "arn:aws:sns:ap-south-1:133459798589:aws-controltower-AggregateSecurityNotifications"
        }
    }

    ephemeral_storage {
        size = 512
    }

    timeouts {}

    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_permission" "s3_fim" {
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.s3_fim_forwarder.function_name
    principal     = "s3.amazonaws.com"
    source_arn    = aws_s3_bucket.ups_uat_loki.arn
    statement_id  = "allow"
}


# resource "aws_sns_topic" "s3_fim_topic" {
#   name = "s3-fim-event-topic"

#   policy = <<POLICY
# {
#     "Version":"2012-10-17",
#     "Statement":[{
#         "Effect": "Allow",
#         "Principal": { "Service": "s3.amazonaws.com" },
#         "Action": "SNS:Publish",
#         "Resource": "arn:aws:sns:*:*:s3-fim-event-topic",
#         "Condition":{
#             "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.ups_uat_loki.arn}"}
#         }
#     }]
# }
# POLICY
# }




resource "aws_s3_bucket_notification" "loki_bucket_notification" {
    bucket = aws_s3_bucket.ups_uat_loki.id
    
    topic {
        events    = [
            "s3:ObjectRemoved:*",
        ]
        topic_arn = aws_sns_topic.s3_event_forwarder.arn
    }

    lambda_function {
        lambda_function_arn = aws_lambda_function.s3_fim_forwarder.arn
        events              = ["s3:ObjectCreated:*"]
    }
}

# resource "aws_sns_topic_subscription" "subscribe_to_loki_bucket_fim" {
#   topic_arn = aws_sns_topic.s3_fim_topic.arn
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.s3_fim_forwarder.arn
# }