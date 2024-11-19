output "transfer_endpoint" {
  description = "The endpoint of the Transfer Server"
  value       = var.enabled ? join("", aws_transfer_server.default.*.endpoint) : null
}

output "elastic_ips" {
  description = "Provisioned Elastic IPs"
  value       = var.enabled && var.eip_enabled ? aws_eip.sftp.*.id : null
}

output "s3_access_role_arns" {
  description = "Role ARNs for the S3 access"
  value       = { for user, val in aws_iam_role.s3_access_for_sftp_users : user => val.arn }
}
