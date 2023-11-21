resource "aws_vpc" "prod_noncde_clientvpn" {
  ipv4_ipam_pool_id = "ipam-pool-028cadfba5189b4e6"
  cidr_block       = "10.0.192.0/26"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "prod-noncde-clientvpn-1"
    Environment = "prod"
    Terraform = "true"
  }
}


resource "aws_flow_log" "prod_noncde_clientvpn_vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.ups_flow_logs_creator.arn
  log_destination = aws_cloudwatch_log_group.prod_noncde_clientvpn_vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id = aws_vpc.prod_noncde_clientvpn.id
}

resource "aws_cloudwatch_log_group" "prod_noncde_clientvpn_vpc_flow_logs" {
  name = "prod-noncde-clientvpn-vpc-flow-logs"
}


resource "aws_subnet" "clientvpn_private1" {
  vpc_id     = aws_vpc.prod_noncde_clientvpn.id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.192.0/27"

  tags = merge(local.tags,tomap({"Name" = "clientvpn-private1"}))
}

resource "aws_subnet" "clientvpn_private2" {
  vpc_id     = aws_vpc.prod_noncde_clientvpn.id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.192.32/27"

  tags = merge(local.tags,tomap({"Name" = "clientvpn-private2"}))
}

output "prod_noncde_infra_clientvpn_private1_sub_cidr" {
  value = aws_subnet.clientvpn_private1.cidr_block
}

output "prod_noncde_infra_clientvpn_private2_sub_cidr" {
  value = aws_subnet.clientvpn_private2.cidr_block
}

resource "aws_route_table" "clientvpn_private_rt" {
  vpc_id     = aws_vpc.prod_noncde_clientvpn.id

 route {
    cidr_block = aws_vpc.prod_noncde_infra_1.cidr_block
    transit_gateway_id = module.tgw.ec2_transit_gateway_id
  }

  tags = merge(local.tags,tomap({"Name" = "clientvpn-private-rt"}))
}

resource "aws_route_table_association" "clientvpn_private_rt_association1" {
  subnet_id      = aws_subnet.clientvpn_private1.id
  route_table_id = aws_route_table.clientvpn_private_rt.id
}

resource "aws_route_table_association" "clientvpn_private_rt_association2" {
  subnet_id      = aws_subnet.clientvpn_private2.id
  route_table_id = aws_route_table.clientvpn_private_rt.id
}


# aws_security_group.client_vpn1_sg:
resource "aws_security_group" "client_vpn1_sg" {
    description = "client vpn1 sg group"
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
            cidr_blocks      = []
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = true
            to_port          = 0
        },
    ]
    name        = "client-vpn1-sg"
   
    vpc_id      = aws_vpc.prod_noncde_clientvpn.id

    tags = merge(local.tags,tomap({"Name" = "client-vpn-sg"}))
}

resource "aws_cloudwatch_log_group" "prod_noncde_clientvpn_logs" {
  name = "prod-noncde-clientvpn-logs"
}


# aws_ec2_client_vpn_endpoint.client_vpn1:
resource "aws_ec2_client_vpn_endpoint" "client_vpn1" {
    client_cidr_block      = "172.16.0.0/22"
    description            = "client-vpn1"
    dns_servers            = [
        "10.0.192.2",
        "8.8.4.4"
    ]
    security_group_ids     = [
        aws_security_group.client_vpn1_sg.id
    ]
    self_service_portal    = "enabled"
    server_certificate_arn = "arn:aws:acm:ap-south-1:954249198481:certificate/700d35a2-8100-443b-97b5-63a650a70787"
    session_timeout_hours  = 8
    split_tunnel           = true

    tags = merge(local.tags,tomap({"Name" = "client-vpn1"}))
    transport_protocol     = "udp"
    vpc_id                 = aws_vpc.prod_noncde_clientvpn.id
    vpn_port               = 443

    authentication_options {
        saml_provider_arn              = "arn:aws:iam::954249198481:saml-provider/noncde-main"
        self_service_saml_provider_arn = "arn:aws:iam::954249198481:saml-provider/noncde-main-self-service"
        type                           = "federated-authentication"
    }

    client_connect_options {
        enabled = false
    }

    client_login_banner_options {
        banner_text = "Logged into Prod. Careful !!"
        enabled     = true
    }

    connection_log_options {
        cloudwatch_log_group  = aws_cloudwatch_log_group.prod_noncde_clientvpn_logs.name
        enabled               = true
    }
}

resource "aws_ec2_client_vpn_network_association" "client_vpn1_auth1" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    subnet_id              = aws_subnet.clientvpn_private1.id

    timeouts {}
}

resource "aws_ec2_client_vpn_network_association" "client_vpn1_auth2" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    subnet_id              = aws_subnet.clientvpn_private2.id

    timeouts {}
}

#aws_ec2_client_vpn_authorization_rule.client_vpn1_auth_rule:
resource "aws_ec2_client_vpn_authorization_rule" "authorize_prod_noncde_clientvpn_vpc" {
    authorize_all_groups   = true
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    target_network_cidr    = aws_vpc.prod_noncde_clientvpn.cidr_block
    timeouts {}
}

resource "aws_ec2_client_vpn_authorization_rule" "authorize_prod_k8s_cluster_subnets" {
    count = length(local.prod_k8s_cluster_private_subnets)
    authorize_all_groups   = true
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    target_network_cidr    = local.prod_k8s_cluster_private_subnets[count.index].cidr_block
    timeouts {}
}

resource "aws_ec2_client_vpn_authorization_rule" "authorize_prod_k8s_noncde_private" {
    count = length(local.prod_noncde_private_subnets)
    authorize_all_groups   = true
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    target_network_cidr    = local.prod_noncde_private_subnets[count.index].cidr_block
    timeouts {}
}

resource "aws_ec2_client_vpn_authorization_rule" "authorize_prod_k8s_noncde_private_2" {
    count = length(local.prod_noncde_private_subnets_2)
    authorize_all_groups   = true
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    target_network_cidr    = local.prod_noncde_private_subnets_2[count.index].cidr_block
    timeouts {}
}



resource "aws_ec2_client_vpn_route" "prod_k8s_cluster_route_1" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_k8s_cluster_private1.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_cluster_route_2" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_k8s_cluster_private2.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}


resource "aws_ec2_client_vpn_route" "prod_k8s_noncde_private_1" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_noncde_private1.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_noncde_private_2" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_noncde_private2.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_noncde_private_3" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_noncde_private3.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_noncde_private_4" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_noncde_private4.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_noncde_private_5" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_noncde_private5.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_noncde_private_6" {
    count = length(local.client_vpn_subnets)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = aws_subnet.prod_noncde_private6.cidr_block
    target_vpc_subnet_id   = local.client_vpn_subnets[count.index].id

    timeouts {}
}





