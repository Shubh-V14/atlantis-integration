locals {
    stage_infra_vpc1_name = "stage-infra1"
    stage_infra_vpc1_cidr = "10.0.64.0/20"
}

data "terraform_remote_state" "shared_infra" {
  backend = "s3"

  config = {
    bucket = "ups-infra-state"
    region = "ap-south-1"
    key = "vpc/deployment/Shared-Infra/plus/terraform.tfstate"
    role_arn = "arn:aws:iam::776633114724:role/tf-state-manager"
    session_name = "terraform"
  }
}

locals {
  shared_infra_1_vpc_id = data.terraform_remote_state.shared_infra.outputs.shared_infra_1_id
  shared_infra_tgw_id = data.terraform_remote_state.shared_infra.outputs.ups_tgw_id
  shared_infra_clientvpn_private1_sub_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private1_sub_cidr
  shared_infra_clientvpn_private2_sub_cidr = data.terraform_remote_state.shared_infra.outputs.shared_infra_clientvpn_private2_sub_cidr
  egress_ips = {"utk": {"ips": ["10.172.223.113/32", "10.172.223.15/32", "10.184.14.40/32"]}}
  hitachi_ips = {"visa": {"ips": ["172.18.24.40/32", "172.18.24.41/32"]}}
}

resource "aws_ram_resource_share_accepter" "accept_tgw_from_shared_infra" {
  share_arn = data.terraform_remote_state.shared_infra.outputs.tgw_external_share_arns["${var.account_id}"]["resource_share_arn"]
}

resource "aws_vpc" "stage_infra_1" {
  ipv4_ipam_pool_id = "ipam-pool-002baa6c33f12bc6c"
  cidr_block       = local.stage_infra_vpc1_cidr
  instance_tenancy = "default"

  tags = {
    Name = "stage-infra-1"
    Environment = "stage"
    Terraform = "true"
  }
}

output "vpc_stage_infra_1_id" {
  value = aws_vpc.stage_infra_1.id
}

resource "aws_security_group" "stage_app_k8s_sg1" {
    description = "Communication between the control plane and worker nodegroups"
    egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    ingress     = [
        {
            cidr_blocks      = [
                local.shared_infra_clientvpn_private1_sub_cidr,
                local.shared_infra_clientvpn_private2_sub_cidr
            ]
            description      = ""
            from_port        = 443
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 443
        },
    ]
    tags = {
      Name = "stage-app-k8s-sg1"
      Environment = "stage"
      Terraform = "true"
    }
    tags_all    = {}
    vpc_id      = aws_vpc.stage_infra_1.id
    timeouts {}
      lifecycle {
    ignore_changes = [
      egress,
      ingress
    ]
  }
}

resource "aws_subnet" "stage_app_k8s_private1" {
  vpc_id     = aws_vpc.stage_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.64.0/22"

  tags = {
    Name = "stage-app-k8s-private1"
    Environment = "stage"
    Terraform = "true"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

output "stage_app_k8s_private1_cidr" {
  value = aws_subnet.stage_app_k8s_private1.cidr_block
}
output "stage_app_k8s_private1" {
  value = aws_subnet.stage_app_k8s_private1
}
output "stage_app_k8s_private2" {
  value = aws_subnet.stage_app_k8s_private2
}

output "stage_app_k8s_private2_cidr" {
  value = aws_subnet.stage_app_k8s_private2.cidr_block
}

resource "aws_subnet" "stage_app_k8s_private2" {
  vpc_id     = aws_vpc.stage_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.68.0/22"

  tags = {
    Name = "stage-app-k8s-private2"
    Environment = "stage"
    Terraform = "true"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "stage_app_k8s_public1" {
  vpc_id     = aws_vpc.stage_infra_1.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.72.0/22"

  tags = {
    Name = "stage-app-k8s-public1"
    Environment = "stage"
    Terraform = "true"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "stage_app_k8s_public2" {
  vpc_id     = aws_vpc.stage_infra_1.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.76.0/22"

  tags = {
    Name = "stage-app-k8s-public2"
    Environment = "stage"
    Terraform = "true"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_internet_gateway" "stage_app_k8s_igw" {
  vpc_id     = aws_vpc.stage_infra_1.id

  tags = {
    Name = "stage-app-k8s-igw"
    Environment = "stage"
    Terraform = "true"
  }
}
resource "aws_eip" "stage_app_k8s_ngw_eip" {
  vpc= true
}

resource "aws_nat_gateway" "stage_app_k8s_ngw" {
  allocation_id = aws_eip.stage_app_k8s_ngw_eip.allocation_id
  subnet_id     = aws_subnet.stage_app_k8s_public1.id

  tags = {
    Name = "stage-app-k8s-gw-NAT"
    Environment = "stage"
    Terraform = "true"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.stage_app_k8s_igw]
}

locals {
  stage_db1_private1_cidr = aws_subnet.stage_db1_private1.cidr_block
  stage_db1_private2_cidr = aws_subnet.stage_db1_private2.cidr_block
  stage_infra1_db1_pc_id = aws_vpc_peering_connection.stage_infra1_db1_pc.id
}
resource "aws_route_table" "stage_app_k8s_public_rt" {
  depends_on = [ aws_ram_resource_share_accepter.accept_tgw_from_shared_infra ]
  vpc_id     = aws_vpc.stage_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.stage_app_k8s_igw.id
  }

  route {
    cidr_block = "10.0.0.96/27" #clientvpn
    transit_gateway_id = local.shared_infra_tgw_id
  }

  route {
    cidr_block = "10.0.0.128/27" #clientvpn
    transit_gateway_id = local.shared_infra_tgw_id
  }


  tags = {
    Name = "stage-app-k8s-public-rt"
    Environment = "stage"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "stage_app_k8s_public_rt_association1" {
  subnet_id      = aws_subnet.stage_app_k8s_public1.id
  route_table_id = aws_route_table.stage_app_k8s_public_rt.id
}

resource "aws_route_table_association" "stage_app_k8s_public_rt_association2" {
  subnet_id      = aws_subnet.stage_app_k8s_public2.id
  route_table_id = aws_route_table.stage_app_k8s_public_rt.id
}


resource "aws_route_table" "stage_app_k8s_private_rt" {
  depends_on = [ aws_ram_resource_share_accepter.accept_tgw_from_shared_infra ]
  vpc_id     = aws_vpc.stage_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.stage_app_k8s_ngw.id
  }

  route {
    cidr_block = "10.0.0.96/27" #clientvpn
    transit_gateway_id = local.shared_infra_tgw_id
  }

  route {
    cidr_block = "10.0.0.128/27" #clientvpn
    transit_gateway_id = local.shared_infra_tgw_id
  }

  dynamic "route" {
    for_each = local.egress_ips.utk.ips
    content {
      cidr_block = route.value
      transit_gateway_id = local.shared_infra_tgw_id
    }
  }

  dynamic "route" {
    for_each = local.hitachi_ips.visa.ips
    content {
      cidr_block = route.value
      transit_gateway_id = local.shared_infra_tgw_id
    }
  }

  #connect to db subnet over peering

 route {
    cidr_block = local.stage_db1_private1_cidr
    vpc_peering_connection_id = local.stage_infra1_db1_pc_id
  }




  tags = {
    Name = "stage-app-k8s-private-rt"
    Environment = "stage"
    Terraform = "true"
  }
}

output "stage_app_k8s_private_rt" {
  value = aws_route_table.stage_app_k8s_private_rt.id
}

resource "aws_route_table_association" "stage_app_k8s_private_rt_association1" {
  subnet_id      = aws_subnet.stage_app_k8s_private1.id
  route_table_id = aws_route_table.stage_app_k8s_private_rt.id
}

resource "aws_route_table_association" "stage_app_k8s_private_rt_association2" {
  subnet_id      = aws_subnet.stage_app_k8s_private2.id
  route_table_id = aws_route_table.stage_app_k8s_private_rt.id
}

resource "aws_ram_resource_share" "share_infra_to_stage_application" {
  name                      = local.stage_infra_vpc1_name
  allow_external_principals = false

  tags = {
    Environment = "stage"
    Terraform = "true"
  }
}

variable account_mapping {
  type = map(string)
}


resource "aws_ram_principal_association" "share_infra_to_stage_application" {
  principal          = lookup(var.account_mapping, "Stage-Application", 0)
  resource_share_arn = aws_ram_resource_share.share_infra_to_stage_application.arn
}

locals {
  stage_k8s_public_subnets_arns = [aws_subnet.stage_app_k8s_public1.arn, aws_subnet.stage_app_k8s_public2.arn]
  stage_k8s_private_subnets_arns = [aws_subnet.stage_app_k8s_private1.arn, aws_subnet.stage_app_k8s_private2.arn]
  internal_tgw_id = "tgw-0ba44a757bc9843f6"
}

resource "aws_ram_resource_association" "share_private_subnets_to_stage_application" {
  count = length(local.stage_k8s_private_subnets_arns)
  resource_arn       = local.stage_k8s_private_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_infra_to_stage_application.arn
}

resource "aws_ram_resource_association" "share_public_subnets_to_stage_application" {
  count = length(local.stage_k8s_public_subnets_arns)
  resource_arn       = local.stage_k8s_public_subnets_arns[count.index]
  resource_share_arn = aws_ram_resource_share.share_infra_to_stage_application.arn
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attach_stage_app_k8s_to_tgw" {
  subnet_ids         = [aws_subnet.stage_app_k8s_private1.id, aws_subnet.stage_app_k8s_private2.id]
  transit_gateway_id = local.internal_tgw_id
  vpc_id             = aws_vpc.stage_infra_1.id
  appliance_mode_support = "enable"
}

