locals {
  sftp_users_map = {
    for user in var.sftp_users : user => {
      user_name  = user
      public_key = trimspace(tls_private_key.sftp_user[user].public_key_openssh)
    }
  }
  cloudfront_domain_name = "cdn.${var.project_domain_name}"
  sftp_domain_name       = "sftp.${var.project_domain_name}"
  kubernetes_namespaces = [
    "nvidia-device-plugin",
    "nginx-controller",
    "argo-events",
    "argo-workflows",
    "argo-cd",
    "transcoder",
  ]
}
