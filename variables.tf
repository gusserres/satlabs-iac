################################################################################
# General
################################################################################

variable "profile" {
  description = "Profile being used by the module"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "project_domain_name" {
  type = string
}

variable "default_tags" {
  description = "AWS Tags"
  type        = map(string)
}

################################################################################
# SFTP
################################################################################

variable "sftp_users" {
  type        = list(string)
  description = "SFTP Users"
}

################################################################################
# Route53
################################################################################

variable "route53_domain_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

################################################################################
# VPC
################################################################################

variable "vpc_name" {
  type    = string
  default = ""
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"

}

variable "vpc_private_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_intra_subnets" {
  type    = list(string)
  default = ["10.0.200.0/24", "10.0.201.0/24", "10.0.203.0/24"]
}

variable "vpc_public_subnets" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "vpc_availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

################################################################################
# EKS
################################################################################

variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_version" {
  type = string
}

variable "fargate_profile_name" {
  type    = string
  default = "karpenter"
}

variable "whitelist_ips" {
  type = list(string)
}

################################################################################
# EKS Workloads
################################################################################
