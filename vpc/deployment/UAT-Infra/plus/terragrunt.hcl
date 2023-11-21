include "root" {
  path = find_in_parent_folders()
}

inputs = {
    google_cidrs = read_terragrunt_config("./firewall-prefixlist-cidrs/google_cidr.hcl").inputs.google_cidrs
    aws_cidrs = read_terragrunt_config("./firewall-prefixlist-cidrs/aws_cidr.hcl").inputs.aws_cidrs
    github_ssh_cidrs = read_terragrunt_config("./firewall-prefixlist-cidrs/github_ssh_cidr.hcl").inputs.github_ssh_cidrs
    additional_domains1_cidrs = read_terragrunt_config("./firewall-prefixlist-cidrs/additional_domains1_cidr.hcl").inputs.additional_domains1_cidrs
}

