module "CERT" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.1"

  domain_name = var.route53_domain_name
  zone_id     = var.route53_zone_id

  validation_method = "DNS"

  subject_alternative_names = [
    "*.k8s.${var.route53_domain_name}",
  ]

  wait_for_validation = true

  tags = merge(tomap({ Name = var.route53_domain_name }), var.default_tags)
}
