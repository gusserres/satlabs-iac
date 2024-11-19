################################################################################
# ARGO CD
################################################################################

resource "helm_release" "argo_cd" {
  depends_on = [
    module.EKS,
    kubernetes_namespace_v1.namespaces
  ]
  name          = "argo-cd"
  repository    = "https://argoproj.github.io/argo-helm"
  chart         = "argo-cd"
  version       = "7.4.7"
  namespace     = kubernetes_namespace_v1.namespaces["argo-cd"].metadata[0].name
  force_update  = false
  wait          = false
  recreate_pods = false

  set {
    name  = "global.domain"
    value = "argocd.k8s.${var.route53_domain_name}"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }
  set {
    type  = "string"
    name  = "server.ingress.labels.managed-by-external-dns"
    value = "true"
  }

  # set {
  #   name  = "controller.resources.requests.cpu"
  #   value = "200m"
  # }
  # set {
  #   name  = "controller.resources.requests.memory"
  #   value = "500Mi"
  # }
  # set {
  #   name  = "controller.resources.limits.cpu"
  #   value = "200m"
  # }
  # set {
  #   name  = "controller.resources.limits.memory"
  #   value = "500Mi"
  # }
}

################################################################################
# ARGO Events
################################################################################

resource "helm_release" "argo_events" {
  depends_on = [
    module.EKS,
    kubernetes_namespace_v1.namespaces
  ]
  name          = "argo-events"
  repository    = "https://argoproj.github.io/argo-helm"
  chart         = "argo-events"
  version       = "2.4.7"
  namespace     = kubernetes_namespace_v1.namespaces["argo-events"].metadata[0].name
  force_update  = false
  wait          = false
  recreate_pods = false

}

# ################################################################################
# # ARGO Workflows
# ################################################################################

resource "helm_release" "argo_workflows" {
  depends_on = [
    module.EKS,
    kubernetes_namespace_v1.namespaces
  ]
  name          = "argo-workflows"
  repository    = "https://argoproj.github.io/argo-helm"
  chart         = "argo-workflows"
  version       = "0.42.0"
  namespace     = kubernetes_namespace_v1.namespaces["argo-workflows"].metadata[0].name
  force_update  = false
  wait          = false
  recreate_pods = false

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set_list {
    name  = "controller.workflowNamespaces"
    value = [kubernetes_namespace_v1.namespaces["transcoder"].metadata[0].name]
  }
  set_list {
    name  = "server.authModes"
    value = ["server"]
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }
  set_list {
    name  = "server.authModes"
    value = ["server"]
  }
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }
  set {
    type  = "string"
    name  = "server.ingress.labels.managed-by-external-dns"
    value = "true"
  }
  set_list {
    name  = "server.ingress.hosts"
    value = ["argoworkflows.k8s.${var.route53_domain_name}"]
  }

}
