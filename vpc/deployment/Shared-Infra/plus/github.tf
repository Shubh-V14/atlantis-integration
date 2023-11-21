# # aws_iam_policy.github_actions_policy:
# resource "aws_iam_policy" "github_actions_policy" {
#     description = "github-actions-permissions"
#     name        = "github-actions-permissions"
#     policy      = <<EOT
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "GetAuthorizationToken",
#             "Effect": "Allow",
#             "Action": [
#                 "ecr:GetAuthorizationToken"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Sid": "AllowPushPull",
#             "Effect": "Allow",
#             "Action": [
#                 "ecr:BatchGetImage",
#                 "ecr:BatchCheckLayerAvailability",
#                 "ecr:CompleteLayerUpload",
#                 "ecr:GetDownloadUrlForLayer",
#                 "ecr:InitiateLayerUpload",
#                 "ecr:PutImage",
#                 "ecr:UploadLayerPart"
#             ],
#             "Resource": "arn:aws:ecr:ap-south-1:776633114724:repository/*"
#         }
#     ]
# }
# EOT
#     tags = merge(local.sprinto_prod_tags,tomap({"Name" = "github-actions-policy"}))
# }

# # aws_iam_role.github_actions_role:
# resource "aws_iam_role" "github_actions_role" {
#     assume_role_policy    = jsonencode(
#         {
#             Statement = [
#                 {
#                     Action    = "sts:AssumeRoleWithWebIdentity"
#                     Condition = {
#                         StringEquals = {
#                             "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
#                         }
#                         StringLike   = {
#                             "token.actions.githubusercontent.com:sub" = "repo:upswing-one/*:*"
#                         }
#                     }
#                     Effect    = "Allow"
#                     Principal = {
#                         Federated = "arn:aws:iam::776633114724:oidc-provider/token.actions.githubusercontent.com"
#                     }
#                 },
#             ]
#             Version   = "2012-10-17"
#         }
#     )
#     description           = "github-actions-role"
#     force_detach_policies = false

#     managed_policy_arns   = [
#         "arn:aws:iam::776633114724:policy/github-actions-permissions",
#     ]
#     max_session_duration  = 3600
#     name                  = "github-actions-role"
#     path                  = "/"

#     tags = merge(local.sprinto_prod_tags,tomap({"Name" = "github-actions-role"}))

# }

# # aws_iam_openid_connect_provider.github_actions_role:
# resource "aws_iam_openid_connect_provider" "github_actions_role" {
#     client_id_list  = [
#         "sts.amazonaws.com",
#     ]
#     tags            = {}
#     tags_all        = {}
#     thumbprint_list = [
#         "6938fd4d98bab03faadb97b34396831e3780aea1",
#     ]
#     url             = "https://token.actions.githubusercontent.com"
# }

