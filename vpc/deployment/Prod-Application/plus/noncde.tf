
resource "aws_eip" "prod_noncde_cluster_eip1" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "prod-noncde-cluster-eip1"}))
}

resource "aws_eip" "prod_noncde_cluster_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "prod-noncde-cluster-eip2"}))
}

resource "aws_eip" "prod_noncde_app_eip1" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "prod-noncde-app-eip1"}))
}

resource "aws_eip" "prod_noncde_app_eip2" {
  vpc= true
  tags = merge(local.tags,tomap({"Name" = "prod-noncde-app-eip2"}))
}

