module "TRANSFER_FAMILY_SFTP" {
  depends_on = [
    tls_private_key.sftp_user,
    aws_secretsmanager_secret.sftp_user,
    aws_secretsmanager_secret_version.sftp_user
  ]
  source          = "./_modules/tranfer_family"
  s3_bucket_name  = module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_id
  restricted_home = false
  zone_id         = var.route53_zone_id
  domain_name     = local.sftp_domain_name
  sftp_users      = local.sftp_users_map
  tags            = var.default_tags
}

resource "tls_private_key" "sftp_user" {
  for_each  = toset(var.sftp_users)
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_secretsmanager_secret" "sftp_user" {
  for_each    = toset(var.sftp_users)
  name        = "sftp-user/${each.key}/keys"
  description = "SFTP user keys"
  tags        = var.default_tags
}

resource "aws_secretsmanager_secret_version" "sftp_user" {
  for_each  = toset(var.sftp_users)
  secret_id = aws_secretsmanager_secret.sftp_user[each.key].id
  secret_string = jsonencode({
    privateKey = tls_private_key.sftp_user[each.key].private_key_openssh
    publicKey  = tls_private_key.sftp_user[each.key].public_key_openssh
  })
}

resource "aws_ssm_parameter" "original_media_sfpt_endpoint" {
  name           = "/sftp-server/original-media/endpoint"
  type           = "String"
  value          = null
  insecure_value = module.TRANSFER_FAMILY_SFTP.transfer_endpoint
  tags           = var.default_tags
}
