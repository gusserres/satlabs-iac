######################################################
# Karpenter Custom Resource Definition
# https://github.com/aws/karpenter-provider-aws/tree/main/charts/karpenter-crd
######################################################

resource "helm_release" "karpenter_crd" {
  name          = "karpenter-crd"
  repository    = "oci://public.ecr.aws/karpenter/"
  chart         = "karpenter-crd"
  version       = var.karpenter_version
  namespace     = var.karpenter_namespace
  force_update  = true
  wait          = false
  recreate_pods = false
}

######################################################
# Karpenter Controller
# https://github.com/aws/karpenter-provider-aws/blob/main/charts/karpenter/
######################################################

resource "helm_release" "karpenter" {
  name          = "karpenter"
  repository    = "oci://public.ecr.aws/karpenter/"
  chart         = "karpenter"
  version       = var.karpenter_version
  namespace     = var.karpenter_namespace
  force_update  = false
  wait          = false
  recreate_pods = false

  set {
    type  = "string"
    name  = "settings.clusterEndpoint"
    value = var.eks_cluster_endpoint
  }
  set {
    type  = "string"
    name  = "settings.interruptionQueue"
    value = var.eks_cluster_interruption_queue_name
  }
  set {
    type  = "string"
    name  = "settings.clusterName"
    value = var.eks_cluster_name
  }
  set {
    type  = "string"
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.karpenter_controller_role_arn
  }
  set {
    type  = "string"
    name  = "controller.resources.requests.memory"
    value = "500Mi"
  }
  set {
    type  = "string"
    name  = "controller.resources.requests.cpu"
    value = "300m"
  }
  set {
    type  = "string"
    name  = "controller.resources.limits.memory"
    value = "500Mi"
  }
  set {
    type  = "string"
    name  = "controller.resources.limits.cpu"
    value = "300m"
  }

  # -- Global log level, defaults to 'info'
  #set {
  #   type  = "string"
  #   name  = "logLevel"
  #   value = "debug"
  # },
}
