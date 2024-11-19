module "VPC" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = var.vpc_name
  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.vpc_private_subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1,
    "karpenter.sh/discovery"          = var.eks_cluster_name
  }
  public_subnets = var.vpc_public_subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  intra_subnets = var.vpc_intra_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = true

  tags = merge(tomap({ "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned" }), var.default_tags)
}
