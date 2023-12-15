# variable google_cidrs {
#     type = list(string)
# }
# variable aws_cidrs {
#     type = list(string)
# }
# variable github_ssh_cidrs {
#     type = list(string)
# }

# locals {
#       aws_cidr_splitted = [
#     for i in range(0, length(var.aws_cidrs), 100):
#       slice(var.aws_cidrs, i, i + min( length(var.aws_cidrs) - i, 100))
#   ]
# }

# resource "aws_ec2_managed_prefix_list" "googleapis" {
#     address_family = "IPv4"
#     max_entries    = 200
#     name           = "google-apis"
#     tags           = {}
#     tags_all       = {}

#   dynamic "entry" {
#     for_each = var.google_cidrs
#     content {
#       cidr = entry.value
#     }
#   }
   
# }

# resource "aws_ec2_managed_prefix_list" "aws_ap_south_1" {
#     count          = length(local.aws_cidr_splitted)
#     address_family = "IPv4"
#     max_entries    = 100
#     name           = "aws-mum-list ${count.index}"
#     tags           = {}
#     tags_all       = {}
  
#    dynamic "entry" {
#     for_each = local.aws_cidr_splitted[count.index]
#     content {
#       cidr = entry.value
#     }
#   }
  
# }

# resource "aws_ec2_managed_prefix_list" "github_ssh_for_argocd" {
#     address_family = "IPv4"
#     max_entries    = 13
#     name           = "github-ssh-for-argocd"
#     tags           = {}
#     tags_all       = {}

#       dynamic "entry" {
#     for_each = var.github_ssh_cidrs
#     content {
#       cidr = entry.value
#     }
#   }
# }

# resource "aws_ec2_managed_prefix_list" "additional_domains1" {
#     address_family = "IPv4"
#     max_entries    = 50
#     name           = "additional-domains1"
#     tags           = {}
#     tags_all       = {}
#      entry {
#         cidr        = "104.18.121.25/32"
#         description = "production.cloudflare.docker.com"
#     }
#     entry {
#         cidr        = "104.18.122.25/32"
#         description = "production.cloudflare.docker.com"
#     }
#     entry {
#         cidr        = "104.18.123.25/32"
#         description = "production.cloudflare.docker.com"
#     }
#     entry {
#         cidr        = "104.18.124.25/32"
#         description = "production.cloudflare.docker.com"
#     }
#     entry {
#         cidr        = "104.18.125.25/32"
#         description = "production.cloudflare.docker.com"
#     }
#     entry {
#         cidr        = "142.251.12.82/32"
#         description = "k8s.gcr.io"
#     }
#     entry {
#         cidr        = "18.233.255.200/32"
#         description = "quay.io"
#     }
#     entry {
#         cidr        = "192.0.73.2/32"
#         description = "secure.gravatar.com"
#     }
#     entry {
#         cidr        = "3.224.198.181/32"
#         description = "quay.io"
#     }
#     entry {
#         cidr        = "34.225.41.113/32"
#         description = "quay.io"
#     }
#     entry {
#         cidr        = "44.194.5.25/32"
#         description = "auth.docker.io"
#     }
#     entry {
#         cidr        = "44.207.51.64/32"
#         description = "auth.docker.io"
#     }
#     entry {
#         cidr        = "44.207.96.114/32"
#         description = "auth.docker.io"
#     }
#     entry {
#         cidr        = "52.0.153.11/32"
#         description = "quay.io"
#     }
#     entry {
#         cidr        = "54.144.203.57/32"
#         description = "quay.io"
#     }
#     entry {
#         cidr        = "54.159.249.120/32"
#         description = "quay.io"
#     }

# }