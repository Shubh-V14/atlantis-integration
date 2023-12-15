resource "aws_elasticache_subnet_group" "redis1" {
  name       = "redis1-subnet-group"
  subnet_ids = [local.prod_app_k8s_private1_subnet_id, local.prod_app_k8s_private2_subnet_id]
}

resource "aws_security_group" "prod_redis_sg1" {
    description = "Communication between redis instances and rest of the prod Infrastructure"
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
                local.prod_app_k8s_private1_cidr,
                local.prod_app_k8s_private2_cidr
            ]
            description      = "allow redis port from k8s private subnets"
            from_port        = 6379
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 6379
        },
    ]
    tags = {
      Name = "prod-redis-sg1"
      Environment = "prod"
      Terraform = "true"
    }
    tags_all    = {}
    vpc_id      = local.vpc_prod_infra_1_id
    timeouts {}
}

resource "aws_elasticache_cluster" "redis1" {
  cluster_id           = "redis1"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis1.name
  security_group_ids = [aws_security_group.prod_redis_sg1.id]
}

output "redis1_arn" {
    value = aws_elasticache_cluster.redis1.arn
}
