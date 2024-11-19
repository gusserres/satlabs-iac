resource "aws_media_convert_queue" "test" {
  name = "media_transcoder_queue"
  tags = var.default_tags
}

module "ROLE_MEDIA_CONVERT" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.44"

  depends_on = [
    module.S3_BUCKET_ORIGINAL_MEDIA,
    module.SQS_ORIGINAL_MEDIA
  ]

  trusted_role_services = [
    "mediaconvert.amazonaws.com"
  ]

  create_role       = true
  role_requires_mfa = false

  role_name = "media-convert-role"

  inline_policy_statements = [
    {
      sid = "CreateLogs"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      effect    = "Allow"
      resources = ["*"]
    },
    {
      sid = "S3Bucket"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      effect = "Allow"
      resources = [
        "${module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_arn}/*",
        "${module.S3_BUCKET_TRANSCODED_MEDIA.s3_bucket_arn}/*",
        "${module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_arn}",
        "${module.S3_BUCKET_TRANSCODED_MEDIA.s3_bucket_arn}"
      ]
    }
  ]
  tags = var.default_tags
}
