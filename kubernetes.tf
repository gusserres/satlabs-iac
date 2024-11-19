################################################################################
# EKS Base
################################################################################
module "EKS" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.23"

  depends_on = [module.VPC]

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns                      = {}
    eks-pod-identity-agent       = {}
    kube-proxy                   = {}
    vpc-cni                      = {}
    aws-efs-csi-driver           = {}
    aws-mountpoint-s3-csi-driver = {}
  }

  vpc_id                               = module.VPC.vpc_id
  subnet_ids                           = module.VPC.private_subnets
  control_plane_subnet_ids             = module.VPC.intra_subnets
  cluster_endpoint_public_access_cidrs = var.whitelist_ips

  node_security_group_tags = merge(var.default_tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.eks_cluster_name
  })

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    satlabs-eks = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.small"]

      min_size               = 0
      max_size               = 1
      desired_size           = 0
      autoscaling_group_tags = var.default_tags
      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }


  access_entries = {
    # One access entry with a policy associated
    administrator = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::782620204909:user/gustavo.serres"

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.default_tags
}

module "KARPENTER_CONFIG" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.23"

  # depends_on = [module.EKS]

  cluster_name = "satlabs" # module.EKS.cluster_name 

  enable_pod_identity             = true
  create_pod_identity_association = true
  create_instance_profile         = false

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.default_tags
}

module "KARPENTER" {
  source              = "./_modules/karpenter"
  depends_on          = [module.KARPENTER_CONFIG]
  karpenter_version   = "1.0.0"
  karpenter_namespace = "kube-system"
  manifest_enabled    = false

  eks_cluster_name                    = module.EKS.cluster_name
  eks_cluster_endpoint                = module.EKS.cluster_endpoint
  eks_node_role_name                  = module.KARPENTER_CONFIG.node_iam_role_name
  eks_cluster_interruption_queue_name = module.KARPENTER_CONFIG.queue_name
  karpenter_controller_role_arn       = module.KARPENTER_CONFIG.iam_role_arn
  tags                                = var.default_tags

  karpenter = {
    satlabs-workers = {
      user_data          = templatefile("config/user_data/default.sh.tpl", {})
      is_spot            = true
      instance_type      = ["t3a"]
      instance_size      = ["small", "medium", "large", "xlarge"]
      ami_family         = "AL2023"
      ami_selector_terms = [{ alias = "al2023@latest" }]
      volume_size        = "80Gi"
      limits = {
        cpu    = 32
        memory = "64Gi"
      }
      taints           = []
      node_labels      = {}
      node_annotations = {}
      budgets          = [{ nodes = "50%" }]
    }
    satlabs-gpu = {
      user_data          = templatefile("config/user_data/default.sh.tpl", {})
      is_spot            = false
      instance_type      = ["g6"]
      instance_size      = ["xlarge"]
      ami_family         = "AL2"
      ami_selector_terms = [{ alias = "al2@latest" }]
      volume_size        = "80Gi"
      limits = {
        cpu    = 32
        memory = "64Gi"
      }
      taints = [{
        effect   = "NoSchedule"
        value    = true
        key      = "nvidia.com/gpu"
        operator = ""
        },
      ]
      node_labels      = { preferred = "gpu" }
      node_annotations = {}
      budgets          = [{ nodes = "50%" }]
    }
  }
}

################################################################################
# EKS Namespaces
################################################################################

resource "kubernetes_namespace_v1" "namespaces" {
  for_each = toset(local.kubernetes_namespaces)
  metadata {
    labels = {
      managedByTerraform = "true"
    }

    name = each.key
  }
}

################################################################################
# Nvidia Device Plugin
################################################################################

resource "kubernetes_config_map_v1" "nvidia_device_plugin" {
  metadata {
    name = "nvidia-plugin-configs"
  }
  data = {
    "config" = "${file("${path.module}/config/ndp/default.yaml")}"
  }
}

resource "helm_release" "nvidia_device_plugin" {
  depends_on = [
    module.EKS,
    kubernetes_namespace_v1.namespaces,
    kubernetes_config_map_v1.nvidia_device_plugin
  ]
  name          = "nvdp"
  repository    = "https://nvidia.github.io/k8s-device-plugin"
  chart         = "nvidia-device-plugin"
  version       = "0.16.2"
  namespace     = kubernetes_namespace_v1.namespaces["nvidia-device-plugin"].metadata[0].name
  force_update  = false
  wait          = false
  recreate_pods = false

  set {
    type  = "string"
    name  = "config.name"
    value = kubernetes_config_map_v1.nvidia_device_plugin.metadata[0].name
  }
  set {
    type  = "string"
    name  = "namespaceOverride"
    value = kubernetes_namespace_v1.namespaces["nvidia-device-plugin"].metadata[0].name
  }
  set {
    type  = "string"
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }
  set {
    type  = "string"
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    type  = "string"
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }
  set {
    type  = "string"
    name  = "controller.resources.limits.cpu"
    value = "100m"
  }
  set {
    type  = "string"
    name  = "nodeSelector.preferred"
    value = "gpu"
  }
}

################################################################################
# Metrics Server
################################################################################

resource "helm_release" "metrcis_server" {
  depends_on = [
    module.EKS
  ]
  name          = "metrics-server"
  repository    = "https://kubernetes-sigs.github.io/metrics-server"
  chart         = "metrics-server"
  version       = "3.12.1"
  namespace     = "kube-system"
  force_update  = false
  wait          = false
  recreate_pods = true

}

################################################################################
# AWS Load Balancer Controller
################################################################################

module "ROLE_ALB_CONTROLLER" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.44"

  trusted_role_services = [
    "pods.eks.amazonaws.com"
  ]

  create_role       = true
  role_requires_mfa = false

  role_name = "AmazonEKSLoadBalancerController"

  custom_role_policy_arns = [
    aws_iam_policy.alb_controller.arn
  ]
  tags = var.default_tags
}

resource "aws_iam_policy" "alb_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "Policy for AWS Load Balancer Controller"

  policy = file("${path.module}/config/alb_controller/policy.json")
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  depends_on      = [helm_release.alb_controller]
  cluster_name    = module.EKS.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = module.ROLE_ALB_CONTROLLER.iam_role_arn
}

resource "helm_release" "alb_controller" {
  depends_on = [
    module.EKS,
    module.VPC
  ]
  name          = "aws-load-balancer-controller"
  repository    = "https://aws.github.io/eks-charts"
  chart         = "aws-load-balancer-controller"
  version       = "1.8.2"
  namespace     = "kube-system"
  force_update  = false
  wait          = false
  recreate_pods = true

  set {
    type  = "string"
    name  = "clusterName"
    value = var.eks_cluster_name
  }
  set {
    type  = "string"
    name  = "region"
    value = var.region
  }
  set {
    type  = "string"
    name  = "vpcId"
    value = module.VPC.vpc_id
  }
  set {
    type  = "string"
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }
  set {
    type  = "string"
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    type  = "string"
    name  = "controller.resources.limits.memory"
    value = "128Mi"
  }
  set {
    type  = "string"
    name  = "controller.resources.limits.cpu"
    value = "100m"
  }
  set {
    type  = "string"
    name  = "logLevel"
    value = "info"
  }
}

################################################################################
# External DNS
################################################################################

module "ROLE_EXTERNAL_DNS" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.44"

  trusted_role_services = [
    "pods.eks.amazonaws.com"
  ]

  create_role       = true
  role_requires_mfa = false

  role_name = "AmazonEKSExternalDNS"

  custom_role_policy_arns = [
    aws_iam_policy.external_dns.arn
  ]
  tags = var.default_tags
}

resource "aws_iam_policy" "external_dns" {
  name        = "AllowExternalDNSUpdates"
  path        = "/"
  description = "Policy for External DNS"

  policy = file("${path.module}/config/external_dns/policy.json")
}

resource "aws_eks_pod_identity_association" "external_dns" {
  depends_on      = [helm_release.external_dns]
  cluster_name    = module.EKS.cluster_name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = module.ROLE_EXTERNAL_DNS.iam_role_arn
}

resource "helm_release" "external_dns" {
  depends_on    = [module.EKS]
  name          = "external-dns"
  namespace     = "kube-system"
  repository    = "https://charts.bitnami.com/bitnami"
  chart         = "external-dns"
  version       = "8.3.5"
  wait          = false
  recreate_pods = true
  force_update  = false

  set {
    type  = "string"
    name  = "replicaCount"
    value = "2"
  }
  set {
    type  = "string"
    name  = "resourcesPreset"
    value = "nano"
  }
  set {
    type  = "string"
    name  = "policy"
    value = "sync"
  }
  set {
    type  = "string"
    name  = "replicaCount"
    value = "2"
  }
  set {
    type  = "string"
    name  = "provider"
    value = "aws"
  }
  set {
    type  = "string"
    name  = "txtOwnerId"
    value = var.route53_zone_id
  }
  set {
    type  = "string"
    name  = "domainFilters[0]"
    value = var.route53_domain_name
  }
  set {
    type  = "string"
    name  = "registry"
    value = "txt"
  }
  set {
    type  = "string"
    name  = "txtOwnerId"
    value = "satlabs"
  }
  set {
    type  = "string"
    name  = "sources[0]"
    value = "service"
  }
  set {
    type  = "string"
    name  = "sources[1]"
    value = "ingress"
  }
  set {
    type  = "string"
    name  = "aws.zoneType"
    value = "public"
  }
  set {
    type  = "string"
    name  = "aws.batchChangeSize"
    value = 100
  }
  set {
    type  = "string"
    name  = "aws.region"
    value = var.region
  }
  set {
    type  = "string"
    name  = "aws.zonesCacheDuration"
    value = "5m"
  }
  set {
    type  = "string"
    name  = "labelFilter"
    value = "managed-by-external-dns=true"
  }
}

################################################################################
# NGINX Ingress Controller
################################################################################

locals {
  default_tags_list   = [for k, v in var.default_tags : "${k}=${v}"]
  default_tags_string = join("\\,", local.default_tags_list[*])
}

module "SG_NGINX_CONTROLLER" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"
  #  https://github.com/terraform-aws-modules/terraform-aws-security-group
  name            = "satlabs-nginx-controller"
  use_name_prefix = false
  description     = "Nginx Controller Whitelist"
  vpc_id          = module.VPC.vpc_id
  tags            = var.default_tags

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      cidr_blocks = join(",", var.whitelist_ips)
      description = "Terraform var.whitelist_ips"
    },
    {
      rule        = "http-80-tcp"
      cidr_blocks = join(",", var.whitelist_ips)
      description = "Terraform var.whitelist_ips"
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule = "all-all"
    }
  ]
}

resource "helm_release" "nginx_ingress_controller" {
  depends_on    = [module.EKS, module.SG_NGINX_CONTROLLER, kubernetes_namespace_v1.namespaces]
  name          = "default"
  namespace     = kubernetes_namespace_v1.namespaces["nginx-controller"].metadata[0].name
  repository    = "https://kubernetes.github.io/ingress-nginx"
  chart         = "ingress-nginx"
  version       = "4.10.4"
  wait          = false
  recreate_pods = true
  force_update  = true

  set {
    name  = "controller.ingressClass"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "false"
  }

  set {
    name  = "defaultBackend.enabled"
    value = "true"
  }

  set {
    type  = "string"
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    type  = "string"
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-additional-resource-tags"
    value = local.default_tags_string
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = module.CERT.acm_certificate_arn
  }

  set {
    name  = "controller.service.targetPorts.https"
    value = "http"
  }

  set {
    name  = "controller.service.targetPorts.http"
    value = "http"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
    value = "https"
  }

  # set {
  #   name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-attributes"
  #   value = "access_logs.s3.enabled=true\\,access_logs.s3.bucket=${var.bucket_name}\\,access_logs.s3.prefix=${var.bucket_prefix}"
  # }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-security-groups"
    value = module.SG_NGINX_CONTROLLER.security_group_id
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"
    value = "nginx-ingress-controller"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "TCP"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-connection-idle-timeout"
    value = "3600"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-manage-backend-security-group-rules"
    value = "true"
  }

  timeout = 600
}
