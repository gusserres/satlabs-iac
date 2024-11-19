module "SQS_ORIGINAL_MEDIA" {
  # https://github.com/terraform-aws-modules/terraform-aws-sqs
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 4.2"

  name                = "original-media-processor"
  create_dlq          = true
  create_queue_policy = true
  queue_policy_statements = [
    {
      sid     = "AllowS3SendMessage"
      actions = ["SQS:SendMessage"]
      effect  = "Allow"
      principals = [{
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }]
      conditions = [{
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = ["${module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_arn}"]
        },
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = ["${data.aws_caller_identity.current.account_id}"]
      }]
    }
  ]
  tags = var.default_tags
}
