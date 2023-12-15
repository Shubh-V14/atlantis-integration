
resource "aws_cloudwatch_log_group" "ups_client_vpn1_logs" {
  name              = "/aws/lambda/ups_client_vpn1_logs"
  retention_in_days = 14
  kms_key_id = aws_kms_key.client_vpn_logs.arn
}

resource "aws_subnet" "clientvpn_private1" {
  vpc_id     = local.shared_infra_vpc1_id
  availability_zone_id = "aps1-az1"
  cidr_block = "10.0.0.96/27"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "clientvpn-private1"}))
}

resource "aws_subnet" "clientvpn_private2" {
  vpc_id     = local.shared_infra_1_vpc_id
  availability_zone_id = "aps1-az2"
  cidr_block = "10.0.0.128/27"

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "clientvpn-private2"}))
}

output "shared_infra_clientvpn_private1_sub_cidr" {
  value = aws_subnet.clientvpn_private1.cidr_block
}

output "shared_infra_clientvpn_private2_sub_cidr" {
  value = aws_subnet.clientvpn_private2.cidr_block
}


resource "aws_route_table" "clientvpn_private_rt" {
  vpc_id     = local.shared_infra_1_vpc_id

  route {
    cidr_block = "10.0.64.0/20"
    transit_gateway_id = local.shared_infra_tgw_id
  }

  route {
    cidr_block = "10.0.128.0/19"
    transit_gateway_id = local.shared_infra_tgw_id
  }

   route {
    cidr_block = "10.0.48.0/20"
    transit_gateway_id = local.shared_infra_tgw_id
  }

   route {
    cidr_block = "172.16.2.0/24"
    transit_gateway_id = local.shared_infra_tgw_id
  }

  tags = merge(local.sprinto_prod_tags,tomap({"Name" = "clientvpn-private-rt"}))
}

resource "aws_route_table_association" "clientvpn_private_rt_association1" {
  subnet_id      = aws_subnet.clientvpn_private1.id
  route_table_id = aws_route_table.clientvpn_private_rt.id
}

resource "aws_route_table_association" "clientvpn_private_rt_association2" {
  subnet_id      = aws_subnet.clientvpn_private2.id
  route_table_id = aws_route_table.clientvpn_private_rt.id
}

resource "aws_kms_key" "client_vpn_logs" {
  description             = "Key for encrypting common cloudwatch logs"
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
        "Service"= "logs.ap-south-1.amazonaws.com"
        },
        "Action"= [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*" 
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
   tags = merge(local.sprinto_prod_tags,tomap({"Name" = "client-vpn-logs"}))
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
   
    vpc_id      = data.terraform_remote_state.shared_infra.outputs.shared_infra_1_id

    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "client-vpn-sg"}))
}

resource "aws_acm_certificate" "clientvpn_cert" {
    domain_name               = "server"
    subject_alternative_names = [
        "server",
    ]
    tags                      = {}
    tags_all                  = {}
    validation_method         = "NONE"
    options {
        certificate_transparency_logging_preference = "DISABLED"
    }
}

# aws_ec2_client_vpn_endpoint.client_vpn1:
resource "aws_ec2_client_vpn_endpoint" "client_vpn1" {
    client_cidr_block      = "10.16.0.0/22"
    description            = "client-vpn-3"
    dns_servers            = [
        "10.0.0.2",
        "8.8.4.4",
    ]
    security_group_ids     = [
        aws_security_group.client_vpn1_sg.id
    ]
    self_service_portal    = "enabled"
    server_certificate_arn = aws_acm_certificate.clientvpn_cert.arn
    session_timeout_hours  = 8
    split_tunnel           = true

    tags = merge(local.sprinto_prod_tags,tomap({"Name" = "client-vpn-3"}))
    transport_protocol     = "udp"
    vpc_id                 = data.terraform_remote_state.shared_infra.outputs.shared_infra_1_id
    vpn_port               = 443

    authentication_options {
        saml_provider_arn              = "arn:aws:iam::776633114724:saml-provider/vpn-client-main"
        self_service_saml_provider_arn = "arn:aws:iam::776633114724:saml-provider/vpn-client-self-service-main"
        type                           = "federated-authentication"
    }

    client_connect_options {
        enabled = false
    }

    client_login_banner_options {
        banner_text = "You are logged into Upswing. Play Safe"
        enabled     = true
    }

    connection_log_options {
        cloudwatch_log_group  = "/aws/lambda/ups_client_vpn1_logs"
       #cloudwatch_log_stream = "cvpn-endpoint-06488c3f57dbfdba5-ap-south-1-2022/06/27-nhsuAqnc46hn"
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

# aws_ec2_client_vpn_authorization_rule.client_vpn1_auth_rule:
# resource "aws_ec2_client_vpn_authorization_rule" "client_vpn1_auth_rule" {
#     authorize_all_groups   = true
#     client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
#     target_network_cidr    = "10.0.0.0/8"

#     timeouts {}
# }

# aws_ec2_client_vpn_route.stage_k8s_1_1:
resource "aws_ec2_client_vpn_route" "stage_k8s_1_1" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = "10.0.64.0/20"
    target_vpc_subnet_id   = aws_subnet.clientvpn_private1.id

    timeouts {}
}

# aws_ec2_client_vpn_route.stage_k8s_1_2:
resource "aws_ec2_client_vpn_route" "stage_k8s_1_2" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = "10.0.64.0/20"
    target_vpc_subnet_id   = aws_subnet.clientvpn_private2.id

    timeouts {}
}


resource "aws_ec2_client_vpn_route" "prod_k8s_1_1" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = "10.0.128.0/19"
    target_vpc_subnet_id   = aws_subnet.clientvpn_private1.id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "prod_k8s_1_2" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = "10.0.128.0/19"
    target_vpc_subnet_id   = aws_subnet.clientvpn_private2.id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "upswing_stage_k8s" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = "172.16.2.0/24"
    target_vpc_subnet_id   = aws_subnet.clientvpn_private1.id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "upswing_stage_k8s_2" {
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = "172.16.2.0/24"
    target_vpc_subnet_id   = aws_subnet.clientvpn_private2.id

    timeouts {}
}

#Add route entries on client vpn for k8s private subnets
locals {
vpn_allowed_subnets_cidr = [local.uat_infra_app_k8s_private1_cidr, local.uat_infra_cde_k8s_private1_cidr, local.uat_infra_noncde_k8s_private1_cidr, local.uat_infra_app_k8s_private2_cidr, local.uat_infra_cde_k8s_private2_cidr, local.uat_infra_noncde_k8s_private2_cidr, local.uat_infra_app_k8s_public1_cidr, local.uat_infra_app_k8s_public2_cidr]
}

resource "aws_ec2_client_vpn_route" "k8s_vpn_route_az1" {
    count = length(local.vpn_allowed_subnets_cidr)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = local.vpn_allowed_subnets_cidr[count.index]
    target_vpc_subnet_id   = aws_subnet.clientvpn_private1.id

    timeouts {}
}

resource "aws_ec2_client_vpn_route" "k8s_vpn_route_az2" {
    count = length(local.vpn_allowed_subnets_cidr)
    client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.client_vpn1.id
    destination_cidr_block = local.vpn_allowed_subnets_cidr[count.index]
    target_vpc_subnet_id   = aws_subnet.clientvpn_private2.id

    timeouts {}
}