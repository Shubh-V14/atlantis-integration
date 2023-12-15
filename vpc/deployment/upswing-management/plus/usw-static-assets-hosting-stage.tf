# resource "aws_iam_policy" "usw_static_assets_hosting_permissions" {
#     description = "usw-static-assets-hosting-permissions"
#     name        = "usw-static-assets-hosting-permissions"
#     policy      = <<EOT
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Resource": "arn:aws:iam::537885521837:role/usw-static-assets-hosting-stage",
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOT
#     tags        = {}
#     tags_all    = {}
# }