module "ROUTE53_RECORDS" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "~> 3.1"

  zone_id = data.aws_route53_zone.this.zone_id

  records = [
    {
      name = "cdn.transcoder"
      type = "A"
      alias = {
        name    = module.CLOUDFRONT.cloudfront_distribution_domain_name
        zone_id = module.CLOUDFRONT.cloudfront_distribution_hosted_zone_id
      }
    },
  ]
}
