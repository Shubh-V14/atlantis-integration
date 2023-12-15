resource "aws_networkfirewall_firewall_policy" "firewallp1" {
    description  = "firewallp1"
    name         = "firewallp1"
    tags         = {}
    tags_all     = {}

    firewall_policy {
        stateful_default_actions           = [
            "aws:drop_strict",
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
            priority     = 2
            resource_arn = aws_networkfirewall_rule_group.rg1.arn
        }
        stateful_rule_group_reference {
            priority     = 3
            resource_arn = aws_networkfirewall_rule_group.suricata_rules.arn
        }

        stateful_rule_group_reference {
            priority     = 4 
            resource_arn = "arn:aws:network-firewall:ap-south-1:aws-managed:stateful-rulegroup/ThreatSignaturesDoSStrictOrder" 
         }
        stateful_rule_group_reference {
            priority     = 5 
            resource_arn = "arn:aws:network-firewall:ap-south-1:aws-managed:stateful-rulegroup/ThreatSignaturesBotnetWebStrictOrder" 
         }
    }
}



resource "aws_networkfirewall_rule_group" "rg1"  {
    capacity     = 60
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
              key = "GITHUB_SSH"

              ip_set {
                  definition = [
                      "13.234.176.102/32",
                      "13.234.210.38/32",
                      "20.207.73.82/32",
                      "140.82.112.4/32",
                      "192.30.252.0/22",
                      "185.199.108.0/22",
                      "140.82.112.0/20",
                      "143.55.64.0/20",
                      "2a0a:a440::/29",
                      "2606:50c0::/32",
                      "20.201.28.151/32",
                      "20.205.243.166/32",
                      "20.87.225.212/32",
                      "20.248.137.48/32",
                      "20.207.73.82/32",
                      "20.27.177.113/32",
                      "20.200.245.247/32",
                      "20.175.192.147/32",
                      "20.233.83.145/32",
                      "20.29.134.23/32",
                      "20.201.28.152/32",
                      "20.205.243.160/32",
                      "20.87.225.214/32",
                      "20.248.137.50/32",
                      "20.207.73.83/32",
                      "20.27.177.118/32",
                      "20.200.245.248/32",
                      "20.175.192.146/32",
                      "20.233.83.149/32",
                      "20.29.134.19/32"
                  ]
              }
            }
 
             ip_sets {
              key = "CLIENT_VPN"

              ip_set {
                  definition = [
                      aws_subnet.clientvpn_private1.cidr_block,
                      aws_subnet.clientvpn_private2.cidr_block

                  ]
              }
            }
            ip_sets {
              key = "UTKARSH_IPS"

              ip_set {
                  definition = local.utkarsh_cidrs
              }
            }

            ip_sets {
              key = "UTKARSH_DR_IPS"

              ip_set {
                  definition = local.utkarsh_dr_cidrs
              }
            }

            

        }

        rules_source {
            rules_string = <<-EOT


#SMTP
#Allow outbound smtp queries
#Justification - require by cat2 applications to send emails
pass tcp $HOME_NET any -> $EXTERNAL_NET 587(flow:to_server; sid:411;rev: 1;)
pass tcp $EXTERNAL_NET 587 -> $HOME_NET any(flow:to_client; sid: 412;rev: 1;)


#TLS
#Justification - Allow outgoing tls connection for applications internally
#For outbound tls connections we have multiple vendors and partners and static ip is not given for them
pass tls $HOME_NET  any -> $EXTERNAL_NET 443 (flow:to_server; sid:132191; rev:1;)
pass tls $EXTERNAL_NET 443 -> $HOME_NET any (flow:to_client; sid:132192; rev:1;)
pass tcp $HOME_NET any <> $EXTERNAL_NET 443 (flow: not_established; sid:812291; rev:1;)

#SSH
#Is used to pull the code from github to make the build image
pass ssh $HOME_NET any -> $GITHUB_SSH 22 (flow: to_server; sid:1; rev:1;)
pass ssh $GITHUB_SSH 22 -> $HOME_NET any (flow: to_client; sid:2; rev:1;)
pass tcp $HOME_NET any <> $GITHUB_SSH 22 (flow: not_established; sid: 3; rev: 1;)

#TLS
#Justification - Allow inbound tls connection for applications internally
#For inbound tls connections we have multiple public api endpoints and public(internet) accessibility needs to be present
pass tls $EXTERNAL_NET any -> $HOME_NET 443 (flow:to_server; sid:111; rev:1;)
pass tls $HOME_NET 443 -> $EXTERNAL_NET any (flow:to_client; sid:112; rev:1;)
pass tcp $HOME_NET 443 <> $EXTERNAL_NET any (flow: not_established; sid:812292; rev:1;)




#Bank
#Justification - for tls communication from Upswing to Utkarsh Bank on specific ports
pass tls $HOME_NET any -> $UTKARSH_IPS [8082,8083] (flow:to_server; sid: 131; rev: 1;)
pass tls $UTKARSH_IPS [8082,8083] -> $HOME_NET any (flow:to_client; sid: 135; rev: 1;)
pass tcp $HOME_NET any <> $UTKARSH_IPS [8082,8083] (flow: not_established; sid: 132; rev: 1;)


pass tls $HOME_NET any -> $UTKARSH_DR_IPS [8082,8083] (flow:to_server; sid: 1131; rev: 1;)
pass tls $UTKARSH_DR_IPS [8082,8083] -> $HOME_NET any (flow:to_client; sid: 1135; rev: 1;)
pass tcp $HOME_NET any <> $UTKARSH_DR_IPS [8082,8083] (flow: not_established; sid: 1132; rev: 1;)


#Bank
#Justification - for http communication from Upswing to Utkarsh Bank on specific ports
pass http $HOME_NET any -> $UTKARSH_IPS [8082,8083] (flow:to_server; sid: 231; rev: 1;)
pass http $UTKARSH_IPS [8082,8083] -> $HOME_NET any (flow:to_client; sid: 235; rev: 1;)


pass http $HOME_NET any -> $UTKARSH_DR_IPS [8082,8083] (flow:to_server; sid: 1231; rev: 1;)
pass http $UTKARSH_DR_IPS [8082,8083] -> $HOME_NET any (flow:to_client; sid: 1235; rev: 1;)

#TLS for Shivalik Bank outbound
pass tls $HOME_NET any -> 182.18.142.48 9093 (flow:to_server; sid: 15116; rev:1;)
pass tls 182.18.142.48 9093 -> $HOME_NET any (flow:to_client; sid: 15117; rev:1;)
pass tcp $HOME_NET any <> 182.18.142.48 9093 (flow:not_established; sid: 15118; rev:1;)

#TLS for Tata outbound
pass tls $HOME_NET any -> 20.204.107.22 8443(flow:to_server; sid: 15119; rev:1;)
pass tls 20.204.107.22 8443 -> $HOME_NET any (flow:to_client; sid: 15120; rev:1;)
pass tcp $HOME_NET any <> 20.204.107.22 8443 (flow:not_established; sid: 15121; rev:1;)

#DNS
#Allow outbound dns queries
#Justification - require by all the applications across PIC and NON PCI to have dns queries resolved
pass dns $HOME_NET any -> $EXTERNAL_NET 53 (sid:71; rev:1;)
pass dns $EXTERNAL_NET 53 -> $HOME_NET any (sid:72; rev:1;)
pass udp $HOME_NET any <> $EXTERNAL_NET 53 (flow: not_established; sid: 73; rev: 1;)


#Allow Shivalik sftp

pass tcp $HOME_NET any -> 119.82.81.106 5020 (flow: to_server; sid: 9411; rev:1;)
pass tcp  119.82.81.106 5020 -> $HOME_NET any (flow: to_client; sid: 9412; rev:1;)
pass tcp  119.82.81.106 5020 <> $HOME_NET any (flow: not_established; sid: 9413; rev:1;)

#Allow 443, 15021 from client vpn
#Justification
#Allow 443, 15021 from client vpn for employees to operate on the Infrastructure via kubectl and internal tool endpoints like grafana, argocd, drone
#Do note that client vpn has a separate encryption and security for Upswing Employees

pass tcp $CLIENT_VPN any <> $HOME_NET 443 (sid: 202; rev: 1;)
pass tcp $CLIENT_VPN any <> $HOME_NET 5432 (sid: 204; rev: 1;) 
pass tcp $CLIENT_VPN any <> $HOME_NET 3023 (sid: 205; rev: 1;)

#Allow ubuntu http updates
pass tcp $HOME_NET any <> $EXTERNAL_NET 80 (flow: not_established; sid:1332; rev:1;)
pass http $HOME_NET any -> $EXTERNAL_NET 80 (http.host; content:"archive.ubuntu.com"; startswith; endswith; msg:"matching package updates"; flow:to_server, established; sid:1333; rev:1;)
pass http $EXTERNAL_NET 80 -> $HOME_NET any (http.host; content:"archive.ubuntu.com"; startswith; endswith; msg:"matching package updates"; flow:to_server, established; sid:1334; rev:1;)
pass http $HOME_NET any -> $EXTERNAL_NET 80(http.host; content:"security.ubuntu.com"; startswith; endswith; msg:"matching package updates"; flow:to_server, established; sid:1335; rev:1;)
pass http $EXTERNAL_NET 80 -> $HOME_NET any (http.host; content:"security.ubuntu.com"; startswith; endswith; msg:"matching package updates";flow:to_server, established; sid:1336; rev:1;)

pass http $HOME_NET any -> $EXTERNAL_NET 80(http.host; content:"deb.debian.org"; startswith; endswith; msg:"matching package updates"; flow:to_server, established; sid:1337; rev:1;)
pass http $EXTERNAL_NET 80 -> $HOME_NET any (http.host; content:"deb.debian.org"; startswith; endswith; msg:"matching package updates";flow:to_server, established; sid:1338; rev:1;)

pass http $HOME_NET any -> $EXTERNAL_NET 80(http.host; content:"security.debian.org"; startswith; endswith; msg:"matching package updates"; flow:to_server, established; sid:1339; rev:1;)
pass http $EXTERNAL_NET 80 -> $HOME_NET any (http.host; content:"security.debian.org"; startswith; endswith; msg:"matching package updates";flow:to_server, established; sid:1340; rev:1;)



            EOT
        }

        stateful_rule_options {
            rule_order = "STRICT_ORDER"
        }
    }
}

# aws_networkfirewall_rule_group.suricata_rules:
resource "aws_networkfirewall_rule_group" "suricata_rules" {
    capacity     = 200
    description  = "suricata-rules"
    name         = "suricata-rules"
    type         = "STATEFUL"

    rule_group {

        rules_source {
            rules_string = <<-EOT
                # App layer event  rules
                #
                # SID's fall in the 2260000+ range. See http://doc.emergingthreats.net/bin/view/Main/SidAllocation
                #
                # These sigs fire at most once per connection.
                #
                # A flowint applayer.anomaly.count is incremented for each match. By default it will be 0.
                #
                alert ip any any -> any any (msg:"SURICATA Applayer Mismatch protocol both directions"; flow:established; app-layer-event:applayer_mismatch_protocol_both_directions;  sid:2260000; rev:1;)
                alert ip any any -> any any (msg:"SURICATA Applayer Wrong direction first Data"; flow:established; app-layer-event:applayer_wrong_direction_first_data;  sid:2260001; rev:1;)
                alert ip any any -> any any (msg:"SURICATA Applayer Detect protocol only one direction"; flow:established; app-layer-event:applayer_detect_protocol_only_one_direction;  sid:2260002; rev:1;)
                alert ip any any -> any any (msg:"SURICATA Applayer Protocol detection skipped"; flow:established; app-layer-event:applayer_proto_detection_skipped;  sid:2260003; rev:1;)
                # alert if STARTTLS was not followed by actual SSL/TLS
                alert tcp any any -> any any (msg:"SURICATA Applayer No TLS after STARTTLS"; flow:established; app-layer-event:applayer_no_tls_after_starttls;  sid:2260004; rev:2;)
                # unexpected protocol in protocol upgrade
                alert tcp any any -> any any (msg:"SURICATA Applayer Unexpected protocol"; flow:established; app-layer-event:applayer_unexpected_protocol;  sid:2260005; rev:1;)
                
                #next sid is 2260006
                
                # HTTP event  rules
                #
                # SID's fall in the 2221000+ range. See http://doc.emergingthreats.net/bin/view/Main/SidAllocation
                #
                # These sigs fire at most once per HTTP transaction.
                #
                # A flowint http.anomaly.count is incremented for each match. By default it will be 0.
                #
                alert http any any -> any any (msg:"SURICATA HTTP unknown error"; flow:established; app-layer-event:http.unknown_error; sid:2221000; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP gzip decompression failed"; flow:established; app-layer-event:http.gzip_decompression_failed; sid:2221001; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP request field missing colon"; flow:established,to_server; app-layer-event:http.request_field_missing_colon; sid:2221002; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP response field missing colon"; flow:established,to_client; app-layer-event:http.response_field_missing_colon; sid:2221020; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid request chunk len"; flow:established,to_server; app-layer-event:http.invalid_request_chunk_len; sid:2221003; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid response chunk len"; flow:established,to_client; app-layer-event:http.invalid_response_chunk_len; sid:2221004; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid transfer encoding value in request"; flow:established,to_server; app-layer-event:http.invalid_transfer_encoding_value_in_request; sid:2221005; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid transfer encoding value in response"; flow:established,to_client; app-layer-event:http.invalid_transfer_encoding_value_in_response; sid:2221006; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid content length field in request"; flow:established,to_server; app-layer-event:http.invalid_content_length_field_in_request; sid:2221007; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid content length field in response"; flow:established,to_client; app-layer-event:http.invalid_content_length_field_in_response; sid:2221008; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP status 100-Continue already seen"; flow:established,to_client; app-layer-event:http.100_continue_already_seen; sid:2221009; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP unable to match response to request"; flow:established,to_client; app-layer-event:http.unable_to_match_response_to_request; sid:2221010; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid server port in request"; flow:established,to_server; app-layer-event:http.invalid_server_port_in_request; sid:2221011; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid authority port"; flow:established; app-layer-event:http.invalid_authority_port; sid:2221012; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP request header invalid"; flow:established,to_server; app-layer-event:http.request_header_invalid; sid:2221013; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP response header invalid"; flow:established,to_client; app-layer-event:http.response_header_invalid; sid:2221021; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP missing Host header"; flow:established,to_server; app-layer-event:http.missing_host_header; sid:2221014; rev:1;)
                # Alert if hostname is both part of URL and Host header and they are not the same.
                alert http any any -> any any (msg:"SURICATA HTTP Host header ambiguous"; flow:established,to_server; app-layer-event:http.host_header_ambiguous; sid:2221015; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid request field folding"; flow:established,to_server; app-layer-event:http.invalid_request_field_folding; sid:2221016; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP invalid response field folding"; flow:established,to_client; app-layer-event:http.invalid_response_field_folding; sid:2221017; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP request buffer too long"; flow:established,to_server; app-layer-event:http.request_field_too_long; sid:2221018; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP response buffer too long"; flow:established,to_client; app-layer-event:http.response_field_too_long; sid:2221019; rev:1;)
                # Multipart parser detected generic error.
                alert http any any -> any any (msg:"SURICATA HTTP multipart generic error"; flow:established,to_server; app-layer-event:http.multipart_generic_error; sid:2221022; rev:1;)
                # Multipart header claiming a file to present, but no actual filedata available.
                alert http any any -> any any (msg:"SURICATA HTTP multipart no filedata"; flow:established,to_server; app-layer-event:http.multipart_no_filedata; sid:2221023; rev:1;)
                # Multipart header invalid.
                alert http any any -> any any (msg:"SURICATA HTTP multipart invalid header"; flow:established,to_server; app-layer-event:http.multipart_invalid_header; sid:2221024; rev:1;)
                # Warn when the port in the Host: header doesn't match the actual TCP Server port.
                alert http any any -> any any (msg:"SURICATA HTTP request server port doesn't match TCP port"; flow:established,to_server; app-layer-event:http.request_server_port_tcp_port_mismatch; sid:2221026; rev:1;)
                # Host part of URI is invalid
                alert http any any -> any any (msg:"SURICATA HTTP Host part of URI is invalid"; flow:established,to_server; app-layer-event:http.request_uri_host_invalid; sid:2221027; rev:1;)
                # Host header is invalid
                alert http any any -> any any (msg:"SURICATA HTTP Host header invalid"; flow:established,to_server; app-layer-event:http.request_header_host_invalid; sid:2221028; rev:1;)
                # URI is terminated by non-compliant characters. RFC allows for space (0x20), but many implementations permit others like tab and more.
                alert http any any -> any any (msg:"SURICATA HTTP URI terminated by non-compliant character"; flow:established,to_server; app-layer-event:http.uri_delim_non_compliant; sid:2221029; rev:1;)
                # Method is terminated by non-compliant characters. RFC allows for space (0x20), but many implementations permit others like tab and more.
                alert http any any -> any any (msg:"SURICATA HTTP METHOD terminated by non-compliant character"; flow:established,to_server; app-layer-event:http.method_delim_non_compliant; sid:2221030; rev:1;)
                # Request line started with whitespace
                alert http any any -> any any (msg:"SURICATA HTTP Request line with leading whitespace"; flow:established,to_server; app-layer-event:http.request_line_leading_whitespace; sid:2221031; rev:1;)
                
                
                alert http any any -> any any (msg:"SURICATA HTTP Request too many encoding layers"; flow:established,to_server; app-layer-event:http.too_many_encoding_layers; sid:2221032; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP Request abnormal Content-Encoding header"; flow:established,to_server; app-layer-event:http.abnormal_ce_header; sid:2221033; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Request unrecognized authorization method"; flow:established,to_server; app-layer-event:http.request_auth_unrecognized; sid:2221034; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Request excessive header repetition"; flow:established,to_server; app-layer-event:http.request_header_repetition; sid:2221035; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP Response excessive header repetition"; flow:established,to_client; app-layer-event:http.response_header_repetition; sid:2221036; rev:1;)
                
                # This is a suricata limitation rather than anomaly traffic
                # alert http any any -> any any (msg:"SURICATA HTTP Response multipart/byteranges"; flow:established,to_client; app-layer-event:http.response_multipart_byteranges; sid:2221037; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Response abnormal chunked for transfer-encoding"; flow:established,to_client; app-layer-event:http.response_abnormal_transfer_encoding; sid:2221038; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Response chunked with HTTP 0.9 or 1.0"; flow:established,to_client; app-layer-event:http.response_chunked_old_proto; sid:2221039; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Response invalid protocol"; flow:established,to_client; app-layer-event:http.response_invalid_protocol; sid:2221040; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP Response invalid status"; flow:established,to_client; app-layer-event:http.response_invalid_status; sid:2221041; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Request line incomplete"; flow:established,to_server; app-layer-event:http.request_line_incomplete; sid:2221042; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Request double encoded URI"; flow:established,to_server; app-layer-event:http.double_encoded_uri; sid:2221043; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP Invalid Request line"; flow:established,to_server; app-layer-event:http.request_line_invalid; sid:2221044; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP Unexpected Request body"; flow:established,to_server; app-layer-event:http.request_body_unexpected; sid:2221045; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP LZMA reached its memory limit"; flow:established; app-layer-event:http.lzma_memlimit_reached; sid:2221046; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP duplicate content length field in request"; flow:established,to_server; app-layer-event:http.duplicate_content_length_field_in_request; sid:2221047; rev:1;)
                alert http any any -> any any (msg:"SURICATA HTTP duplicate content length field in response"; flow:established,to_client; app-layer-event:http.duplicate_content_length_field_in_response; sid:2221048; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP compression bomb"; flow:established; app-layer-event:http.compression_bomb; sid:2221049; rev:1;)
                
                alert http any any -> any any (msg:"SURICATA HTTP too many warnings"; flow:established; app-layer-event:http.too_many_warnings; sid:2221050; rev:1;)
                
                
                
                # next sid 2221054
                
                # HTTP2 app layer event rules
                #
                # SID's fall in the 2290000+ range. See https://redmine.openinfosecfoundation.org/projects/suricata/wiki/AppLayer
                #
                # These sigs fire at most once per connection.
                #
                
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid frame header"; flow:established; app-layer-event:http2.invalid_frame_header; sid:2290000; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid client magic"; flow:established; app-layer-event:http2.invalid_client_magic; sid:2290001; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid frame data"; flow:established; app-layer-event:http2.invalid_frame_data; sid:2290002; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid header"; flow:established; app-layer-event:http2.invalid_header; sid:2290003; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid frame length"; flow:established; app-layer-event:http2.invalid_frame_length; sid:2290004; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 header frame with extra data"; flow:established; app-layer-event:http2.extra_header_data; sid:2290005; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 too long frame data"; flow:established; app-layer-event:http2.long_frame_data; sid:2290006; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 stream identifier reuse"; flow:established; app-layer-event:http2.stream_id_reuse; sid:2290007; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid HTTP1 settings during upgrade"; flow:established; app-layer-event:http2.invalid_http1_settings; sid:2290008; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 failed decompression"; flow:established; app-layer-event:http2.failed_decompression; sid:2290009; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 invalid range header"; flow:established; app-layer-event:http2.invalid_range; sid:2290010; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 variable-length integer overflow"; flow:established; app-layer-event:http2.header_integer_overflow; sid:2290011; rev:1;)
                alert http2 any any -> any any (msg:"SURICATA HTTP2 too many streams"; flow:established; app-layer-event:http2.too_many_streams; sid:2290012; rev:1;)
                
                # TLS event  rules
                #
                # SID's fall in the 2230000+ range. See http://doc.emergingthreats.net/bin/view/Main/SidAllocation
                #
                # These sigs fire at most once per connection.
                #
                # A flowint tls.anomaly.count is incremented for each match. By default it will be 0.
                #
                alert tls any any -> any any (msg:"SURICATA TLS invalid SSLv2 header"; flow:established; app-layer-event:tls.invalid_sslv2_header; sid:2230000; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid TLS header"; flow:established; app-layer-event:tls.invalid_tls_header; sid:2230001; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid record version"; flow:established; app-layer-event:tls.invalid_record_version; sid:2230015; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid record type"; flow:established; app-layer-event:tls.invalid_record_type; sid:2230002; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid handshake message"; flow:established; app-layer-event:tls.invalid_handshake_message; sid:2230003; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid certificate"; flow:established; app-layer-event:tls.invalid_certificate; sid:2230004; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid length"; flow:established; app-layer-event:tls.certificate_invalid_length; sid:2230007; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS error message encountered"; flow:established; app-layer-event:tls.error_message_encountered; sid:2230009; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid record/traffic"; flow:established; app-layer-event:tls.invalid_ssl_record; sid:2230010; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS heartbeat encountered"; flow:established; app-layer-event:tls.heartbeat_message; sid:2230011; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS overflow heartbeat encountered, possible exploit attempt (heartbleed)"; flow:established; app-layer-event:tls.overflow_heartbeat_message; reference:cve,2014-0160; sid:2230012; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid heartbeat encountered, possible exploit attempt (heartbleed)"; flow:established; app-layer-event:tls.invalid_heartbeat_message; reference:cve,2014-0160; sid:2230013; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid encrypted heartbeat encountered, possible exploit attempt (heartbleed)"; flow:established; app-layer-event:tls.dataleak_heartbeat_mismatch; reference:cve,2014-0160; sid:2230014; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS multiple SNI extensions"; flow:established,to_server; app-layer-event:tls.multiple_sni_extensions; sid:2230016; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid SNI type"; flow:established,to_server; app-layer-event:tls.invalid_sni_type; sid:2230017; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS invalid SNI length"; flow:established,to_server; app-layer-event:tls.invalid_sni_length; sid:2230018; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS handshake invalid length"; flow:established; app-layer-event:tls.handshake_invalid_length; sid:2230019; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS too many records in packet"; flow:established; app-layer-event:tls.too_many_records_in_packet; sid:2230020; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid version"; flow:established; app-layer-event:tls.certificate_invalid_version; sid:2230021; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid serial"; flow:established; app-layer-event:tls.certificate_invalid_serial; sid:2230022; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid algorithm identifier"; flow:established; app-layer-event:tls.certificate_invalid_algorithmidentifier; sid:2230023; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid x509 name"; flow:established; app-layer-event:tls.certificate_invalid_x509name; sid:2230024; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid date"; flow:established; app-layer-event:tls.certificate_invalid_date; sid:2230025; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid extensions"; flow:established; app-layer-event:tls.certificate_invalid_extensions; sid:2230026; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid der"; flow:established; app-layer-event:tls.certificate_invalid_der; sid:2230027; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid subject"; flow:established; app-layer-event:tls.certificate_invalid_subject; sid:2230028; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid issuer"; flow:established; app-layer-event:tls.certificate_invalid_issuer; sid:2230029; rev:1;)
                alert tls any any -> any any (msg:"SURICATA TLS certificate invalid validity"; flow:established; app-layer-event:tls.certificate_invalid_validity; sid:2230030; rev:1;)
                
                #next sid is 2230031
                
                # Emerging Threats
                #
                # This distribution may contain rules under two different licenses.
                #
                #  Rules with sids 1 through 3464, and 100000000 through 100000908 are under the GPLv2.
                #  A copy of that license is available at http://www.gnu.org/licenses/gpl-2.0.html
                #
                #  Rules with sids 2000000 through 2799999 are from Emerging Threats and are covered under the BSD License
                #  as follows:
                #
                #*************************************************************
                #  Copyright (c) 2003-2016, Emerging Threats
                #  All rights reserved.
                #
                #  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
                #  following conditions are met:
                #
                #  * Redistributions of source code must retain the above copyright notice, this list of conditions and the following
                #    disclaimer.
                #  * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
                #    following disclaimer in the documentation and/or other materials provided with the distribution.
                #  * Neither the name of the nor the names of its contributors may be used to endorse or promote products derived
                #    from this software without specific prior written permission.
                #
                #  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
                #  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
                #  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
                #  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
                #  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
                #  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
                #  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
                #
                #*************************************************************
                #
                #
                #
                
                alert http $EXTERNAL_NET any -> $HOME_NET any (msg:"ET EXPLOIT Possible CVE-2014-3704 Drupal SQLi attempt URLENCODE 22"; flow:established,to_server; content:"%6ea%6de%5b"; nocase; fast_pattern:only; http_client_body; pcre:"/(?:^|&|Content-Disposition[\x3a][^\n]*?name\s*?=\s*?[\x22\x27])\%6ea\%6de\%5b[^\x5d]*?\W/Pi"; reference:url,pastebin.com/F2Dk9LbX; sid:2019443; rev:2;)
                alert tcp $EXTERNAL_NET [21,25,110,143,443,465,587,636,989:995,5061,5222] -> $HOME_NET any (msg:"ET EXPLOIT FREAK Weak Export Suite From Server (CVE-2015-0204)"; flow:established,from_server; content:"|16 03|"; depth:2; byte_test:1,<,4,0,relative; content:"|02|"; distance:3; within:1; byte_jump:1,37,relative; content:"|00 19|"; within:2; fast_pattern; threshold:type limit,track by_dst,count 1,seconds 1200; reference:url,blog.cryptographyengineering.com/2015/03/attack-of-week-freak-or-factoring-nsa.html; reference:cve,2015-0204; reference:cve,2015-1637; sid:2020661; rev:3;)
            EOT
        }

        stateful_rule_options {
            rule_order = "STRICT_ORDER"
        }
    }
}