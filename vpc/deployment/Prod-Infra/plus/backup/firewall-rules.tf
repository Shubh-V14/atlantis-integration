resource "aws_networkfirewall_firewall_policy" "firewallp1" {
    description  = "firewallp1"
    name         = "firewallp1"
    tags         = {}
    tags_all     = {}

    firewall_policy {
        stateful_default_actions           = [
            "aws:alert_strict",
        ]
        stateless_default_actions          = [
            "aws:forward_to_sfe",
        ]
        stateless_fragment_default_actions = [
            "aws:forward_to_sfe",
        ]

        stateful_engine_options {
            rule_order = "STRICT_ORDER"
        }

        stateful_rule_group_reference {
            priority     = 1
            resource_arn = aws_networkfirewall_rule_group.allow_aws_mum_range.arn
        }
        stateful_rule_group_reference {
            priority     = 2
            resource_arn = aws_networkfirewall_rule_group.rg1.arn
        }
    }
}



variable google_cidrs {
    type = list(string)
}
variable aws_cidrs {
    type = list(string)
}
variable github_ssh_cidrs {
    type = list(string)
}
variable additional_domains1_cidrs {
    type = set(object({
        cidr = string
        description = string
    }))
}


resource "aws_networkfirewall_rule_group" "allow_aws_mum_range"  {
    capacity     = 10
    description  = "allow-aws-mumbai-services"
    name         = "allow-aws-mumbai-services"
    tags         = {}
    tags_all     = {}
    type         = "STATEFUL"

    rule_group {
        rule_variables {
            ip_sets {
                key = "HOME_NET"

                ip_set {
                    definition = [
                        "10.0.0.0/12",
                    ]
                }
            }

            port_sets {
                key = "EXTERNAL_NET"

                port_set {
                    definition = [
                        "!$HOME_NET",
                    ]
                }
            }

            ip_sets {
              key = "AWS_MUMBAI"

              ip_set {
                  definition = var.aws_cidrs
              }
            }
        }

        rules_source {
            rules_string = <<-EOT
                pass tls $HOME_NET any -> $AWS_MUMBAI 443 (sid:1; rev:1;)
                pass tls  $AWS_MUMBAI 443 -> $HOME_NET any (flow: to_client; sid:2; rev:1;)
            EOT
        }

        stateful_rule_options {
            rule_order = "STRICT_ORDER"
        }
    }

}

locals {
    k8s_public_cidrs = [aws_subnet.prod_app_k8s_public1.cidr_block,aws_subnet.prod_app_k8s_public2.cidr_block ]
    k8s_private_cidrs = [aws_subnet.prod_app_k8s_private1.cidr_block,aws_subnet.prod_app_k8s_private2.cidr_block ]
}

resource "aws_networkfirewall_rule_group" "rg1"  {
    capacity     = 30
    description  = "r1"
    name         = "r1"
    tags         = {}
    tags_all     = {}
    type         = "STATEFUL"

    rule_group {
        rule_variables {
            ip_sets {
                key = "EXTERNAL_NET"

                ip_set {
                    definition = [
                        "!$HOME_NET",
                    ]
                }
            }
            ip_sets {
                key = "HOME_NET"

                ip_set {
                    definition = [
                        "10.0.0.0/12",
                    ]
                }
            }
            ip_sets {
              key = "GOOGLE_APIS"

              ip_set {
                  definition = var.google_cidrs
              }
            }
            ip_sets {
              key = "GITHUB_SSH"

              ip_set {
                  definition = var.github_ssh_cidrs
              }
            }
            ip_sets {
              key = "EXTRA_DOMAINS"

              ip_set {
                  definition = var.additional_domains1_cidrs[*].cidr
              }
            }
              ip_sets {
              key = "K8S_PUBLIC"

              ip_set {
                  definition = local.k8s_public_cidrs
              }
            }
              ip_sets {
              key = "K8S_PRIVATE"

              ip_set {
                  definition = local.k8s_private_cidrs
              }
            }

        }

        rules_source {
            rules_string = <<-EOT
                pass ssh $HOME_NET any -> $GITHUB_SSH 22 (sid:1; rev:1;)
                pass ssh $GITHUB_SSH 22 -> $HOME_NET any (flow: to_client; sid:2; rev:1;)
                pass tls $HOME_NET any -> $GOOGLE_APIS 443 (sid:3; rev:1;)
                pass tls $GOOGLE_APIS 443 ->  $HOME_NET any (flow: to_client; sid:4; rev:1;)
                pass tls $HOME_NET any -> $EXTRA_DOMAINS 443 (sid:5; rev:1;)
                pass tls $EXTRA_DOMAINS 443 ->  $HOME_NET any (flow: to_client; sid:6; rev:1;)
                pass ntp $HOME_NET any -> $EXTERNAL_NET 123 (sid:7; rev:1;)
                pass ntp $EXTERNAL_NET 123 -> $HOME_NET any (flow: to_client; sid:8; rev:1;)
                alert tls $HOME_NET any -> $EXTERNAL_NET any (sid:132191; rev:1;)
                pass tls $HOME_NET any -> $EXTERNAL_NET any (sid:892191; rev:1;)
                drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content: "facebook.com"; sid:491191; rev:1;)
                alert http $HOME_NET any -> $EXTERNAL_NET any (sid:191191; rev:1;)
                pass http $HOME_NET any -> $EXTERNAL_NET any (sid:891191; rev:1;)
                alert udp $HOME_NET any -> $EXTERNAL_NET any (sid:112231; rev:1;)
                pass udp $HOME_NET any -> $EXTERNAL_NET any (sid:812231; rev:1;)
                alert ssh $HOME_NET any -> $EXTERNAL_NET any (sid:512231; rev:1;)
                pass ssh $HOME_NET any -> $EXTERNAL_NET any (sid:511231; rev:1;)
                alert ntp $HOME_NET any -> $EXTERNAL_NET any (sid:517231; rev:1;)
                pass ntp $HOME_NET any -> $EXTERNAL_NET any (sid:119231; rev:1;)
                pass tls $K8S_PUBLIC any -> $K8S_PRIVATE any (sid: 123; rev:1;)
                pass tcp $HOME_NET any <> $EXTERNAL_NET any (flow: not_established; sid:812291; rev:1;)
                alert tcp $HOME_NET any -> $EXTERNAL_NET any (sid:192191; rev:1;)
                pass tcp $HOME_NET any <> $EXTERNAL_NET any (sid:812293; rev:1;)
                pass tcp $K8S_PUBLIC any <> $K8S_PRIVATE any (sid:125; rev:1;)
            EOT
        }

        stateful_rule_options {
            rule_order = "STRICT_ORDER"
        }
    }
}