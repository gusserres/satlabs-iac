module "CLOUDFRONT" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 3.4"

  aliases = [local.cloudfront_domain_name]

  comment             = "Media distribution"
  enabled             = true
  staging             = false
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  create_monitoring_subscription = false

  create_origin_access_control = true
  origin_access_control = {
    s3_oac = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    s3_oac = {
      domain_name           = module.S3_BUCKET_TRANSCODED_MEDIA.s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_oac"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_oac"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    use_forwarded_values = false

    cache_policy_id            = "b2884449-e4de-46a7-ac36-70bc7f1ddd6d"
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }

  logging_config = {
    bucket = module.S3_BUCKET_CF_LOG.s3_bucket_bucket_domain_name
    prefix = "cloudfront"
  }

  viewer_certificate = {
    acm_certificate_arn = module.ACM.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  geo_restriction = {
    restriction_type = "whitelist"
    locations        = ["BR", "PT"]
  }

  tags = var.default_tags
}
