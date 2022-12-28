provider "aws" {
  region = var.dr_region
}

#--------------- Lambda IAM Permissions-----------------------------------------
resource "aws_iam_role" "lambda" {
  name               = "${var.name}-drs-templatemanager-role"
  tags               = var.tags
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda" {
  name   = "${var.name}-drs-templatemanager-policy"
  tags   = var.tags
  policy = file("${path.module}/../policy.json")
}

resource "aws_iam_policy_attachment" "lambda" {
  name       = "${var.name}-drs-templatemanager-attach"
  roles      = [aws_iam_role.lambda.name]
  policy_arn = aws_iam_policy.lambda.arn
}


#--------------- Lambda Packages------------------------------------------------
data "archive_file" "schedule_drs_templates_lambda_zip" {
  type        = "zip"
  output_path = "lambda_schedule_drs_templates.zip"
  source_file = "${path.module}/../cmd-cron/template-cron-automation"
}

data "archive_file" "set_drs_templates_lambda_zip" {
  type        = "zip"
  output_path = "lambda_set_drs_templates.zip"
  source_file = "${path.module}/../cmd-template/drs-template-manager"
}

#--------------- Lambda Functions-----------------------------------------------
resource "aws_lambda_function" "schedule_drs_templates" {
  function_name    = "${var.name}-schedule-drs-templates"
  description      = "Lambda to Schedule DRS Launch Templates"
  role             = aws_iam_role.lambda.arn
  runtime          = "go1.x"
  handler          = "template-cron-automation"
  filename         = data.archive_file.schedule_drs_templates_lambda_zip.output_path
  source_code_hash = data.archive_file.schedule_drs_templates_lambda_zip.output_base64sha256
  tags             = var.tags
  environment {
    variables = {
      BUCKET = var.bucket_name
    }
  }
}

resource "aws_lambda_function" "set_drs_templates" {
  function_name    = "${var.name}-set-drs-templates"
  description      = "Lambda to Set DRS Launch Templates"
  role             = aws_iam_role.lambda.arn
  runtime          = "go1.x"
  handler          = "drs-template-manager"
  filename         = data.archive_file.set_drs_templates_lambda_zip.output_path
  source_code_hash = data.archive_file.set_drs_templates_lambda_zip.output_base64sha256
  tags             = var.tags
}


#----------------S3 Bucket------------------------------------------------------
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.this.id
  acl    = "private"
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.this.id

  lambda_function {
    id                  = "trigger_set_drs_templates"
    lambda_function_arn = aws_lambda_function.set_drs_templates.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }
  depends_on = [aws_lambda_permission.set_drs_templates]
}

resource "aws_lambda_permission" "set_drs_templates" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.set_drs_templates.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.this.arn
}

#--------------- Lambda Trigger------------------------------------------------
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name}-trigger-schedule-drs-templates"
  description         = "Invoke Lambda via AWS EventBridge"
  schedule_expression = var.cron_schedule
  tags                = var.tags
}

resource "aws_lambda_permission" "schedule_drs_templates" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.schedule_drs_templates.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

resource "aws_cloudwatch_event_target" "schedule" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.schedule_drs_templates.arn
}
