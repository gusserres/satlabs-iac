module "ACM" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.0"

  domain_name               = var.project_domain_name
  zone_id                   = data.aws_route53_zone.this.id
  validation_method         = "DNS"
  subject_alternative_names = ["*.${var.project_domain_name}"]
  tags                      = merge(var.default_tags, tomap({ Name = var.route53_domain_name }))
}
