data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_canonical_user_id" "current" {}
data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}

data "aws_route53_zone" "this" {
  zone_id = var.route53_zone_id
}

data "aws_iam_policy_document" "s3_transcoded_policy" {

  depends_on = [module.CLOUDFRONT]
  # Origin Access Controls
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.S3_BUCKET_TRANSCODED_MEDIA.s3_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.CLOUDFRONT.cloudfront_distribution_arn]
    }
  }
}
