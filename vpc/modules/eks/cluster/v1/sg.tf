resource "aws_security_group" "main" {
    description = "Additional Security Group for EKS Cluster"
    #Allow on 443 for cluster api access
    ingress     = [
        {
            cidr_blocks      = var.allowed_cidrs
            description      = ""
            from_port        = 443
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 443
        }
    ]
    tags = merge(local.tags, {
      Name = "${var.variant}-${var.name}-control-plane-sg"
    })
    vpc_id      = var.vpc_id
}