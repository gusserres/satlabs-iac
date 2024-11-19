module "S3_BUCKET_ORIGINAL_MEDIA" {
  # https://github.com/terraform-aws-modules/terraform-aws-s3-bucket
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1.2"

  bucket        = "original-media-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  acl           = "private"
  force_destroy = true
  tags          = var.default_tags
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  depends_on = [module.S3_BUCKET_ORIGINAL_MEDIA, module.SQS_ORIGINAL_MEDIA]
  bucket     = module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_id
  queue {
    queue_arn     = module.SQS_ORIGINAL_MEDIA.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "media_to_transcode/"
  }
}

resource "aws_s3_object" "media_convert_deafult_config" {
  depends_on = [module.S3_BUCKET_ORIGINAL_MEDIA]
  bucket     = module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_id
  key        = "transcoder_config/media_to_transcode.json"
  source     = "${path.module}/config/media_convert/media_to_transcode.json"
  etag       = filemd5("${path.module}/config/media_convert/media_to_transcode.json")
  tags       = var.default_tags
}

module "S3_BUCKET_TRANSCODED_MEDIA" {
  # https://github.com/terraform-aws-modules/terraform-aws-s3-bucket
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1"

  bucket        = "transcoded-media-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  acl           = "private"
  attach_policy = true
  policy        = data.aws_iam_policy_document.s3_transcoded_policy.json
  tags          = var.default_tags
}

module "S3_BUCKET_CF_LOG" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1"

  bucket = "logs-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  grant = [{
    type       = "CanonicalUser"
    permission = "FULL_CONTROL"
    id         = data.aws_canonical_user_id.current.id
    }, {
    type       = "CanonicalUser"
    permission = "FULL_CONTROL"
    id         = data.aws_cloudfront_log_delivery_canonical_user_id.cloudfront.id
  }]
  force_destroy = true
  tags          = var.default_tags
}
