variable "karpenter" {
  type = map(object({
    user_data = string
    taints = list(object({
      key      = string
      operator = string
      value    = string
      effect   = string
    }))
    is_spot            = bool
    instance_type      = list(string)
    instance_size      = list(string)
    ami_family         = string
    ami_selector_terms = list(any)
    volume_size        = string
    limits = object({
      cpu    = number
      memory = string
    })
    node_labels      = map(string)
    node_annotations = map(string)
    budgets          = list(any)
  }))
  default = {
    workers = {
      user_data          = ""
      taints             = []
      is_spot            = false
      instance_type      = ["t3"]
      instance_size      = ["small", "medium", "large", "xlarge"]
      ami_family         = "AL2"
      ami_selector_terms = [{ alias = "al2@latest" }]
      volume_size        = "80Gi"
      limits = {
        cpu    = 32
        memory = "64Gi"
      }
      node_labels      = {}
      node_annotations = {}
      budgets          = [{ nodes = "10%" }]
    }
  }
}

variable "instance_type" {
  default = ["t3", "c5", "m5", "r5", ]
}

variable "instance_size" {
  default = ["small", "medium", "large", ]
}


variable "eks_cluster_name" {
  type = string
}

variable "eks_cluster_endpoint" {
  type = string
}

variable "eks_node_role_name" {
  type = string
}

variable "eks_cluster_interruption_queue_name" {
  type = string
}

variable "karpenter_version" {
  default = "1.0.0"
}

variable "karpenter_namespace" {
  type    = string
  default = "kube-system"
}

variable "karpenter_controller_role_arn" {
  type = string
}

variable "manifest_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
}
