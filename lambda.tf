module "LAMBDA_MEDIA_TRANSCODER" {
  # https://github.com/terraform-aws-modules/terraform-aws-lambda
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.7"

  depends_on = [
    module.S3_BUCKET_ORIGINAL_MEDIA,
    module.S3_BUCKET_TRANSCODED_MEDIA,
    module.ROLE_MEDIA_CONVERT,
    module.SQS_ORIGINAL_MEDIA
  ]

  function_name            = "media_transcoder"
  description              = "Python function to transcode media using AWS MediaConvert"
  handler                  = "index.lambda_handler"
  runtime                  = "python3.12"
  timeout                  = 30
  attach_policy_statements = true
  publish                  = true

  source_path = "${path.module}/lambda_source_codes/media_transcoder"

  policy = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"

  policy_statements = {
    s3 = {
      effect = "Allow",
      actions = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:*"
      ],
      resources = [
        "${module.S3_BUCKET_ORIGINAL_MEDIA.s3_bucket_arn}/*",
        "${module.S3_BUCKET_TRANSCODED_MEDIA.s3_bucket_arn}/*"
      ]
    },
    iam = {
      effect = "Allow",
      actions = [
        "iam:PassRole"
      ],
      resources = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
      ]
    },
    mediaConvert = {
      effect = "Allow",
      actions = [
        "mediaconvert:CreateJob",
        "mediaconvert:DescribeEndpoints"
      ],
      resources = ["*"]
    }
    sqs = {
      effect = "Allow",
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      resources = ["${module.SQS_ORIGINAL_MEDIA.queue_arn}"]
    }
  }

  event_source_mapping = {
    sqs = {
      event_source_arn        = module.SQS_ORIGINAL_MEDIA.queue_arn
      function_response_types = ["ReportBatchItemFailures"]
      batch_size              = 10
      scaling_config = {
        maximum_concurrency = 20
      }
    }
  }

  allowed_triggers = {
    sqs = {
      principal  = "sqs.amazonaws.com"
      source_arn = module.SQS_ORIGINAL_MEDIA.queue_arn
    }
  }

  environment_variables = {
    DESTINATION_BUCKET = module.S3_BUCKET_TRANSCODED_MEDIA.s3_bucket_id
    MEDIACONVERT_ROLE  = module.ROLE_MEDIA_CONVERT.iam_role_arn
  }

  tags = var.default_tags
}
