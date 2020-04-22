provider "aws" {
  region = "us-west-2"
  allowed_account_ids = ["585193511743"]
}

resource "aws_s3_bucket" "deployables" {
  bucket = "scimma-deployables"
  acl = "private"
}

# Note that the following two data references have a bootstrapping problem. They
# need to have the contents managed from outside of Terraform, since we want to
# make modifications to them without running 'terraform apply.' That means that
# they can't be 'resources', they need to be 'data' sources. In a clean start on
# an empty AWS account, then, these keys will not exist.
#
# That means that the # Lambda will not be creatable though because these keys
# won't exist.
data "aws_s3_bucket_object" "script" {
  bucket = aws_s3_bucket.deployables.id
  key = "dontspendtoomuch/latest/script.zip"
}

data "aws_s3_bucket_object" "dependencies" {
  bucket = aws_s3_bucket.deployables.id
  key = "dontspendtoomuch/latest/dependencies.zip"
}

resource "aws_secretsmanager_secret" "slack_hook_url" {
  name = "dontspendtoomuch-slack-hook-url"
  description = "Webhook URL for the dontspendtoomuch Slack app"
  tags = {
    Service = "dontspendtoomuch"
    OwnerEmail = "swnelson@uw.edu"
  }
}

resource "aws_lambda_layer_version" "dependencies" {
  layer_name = "dontspendtoomuch-dependencies"
  description = "Python dependencies for the dontspendtoomuch script"

  s3_bucket = aws_s3_bucket.deployables.id
  s3_key = data.aws_s3_bucket_object.dependencies.key
  s3_object_version = data.aws_s3_bucket_object.dependencies.version_id

  compatible_runtimes = ["python3.6", "python3.7", "python3.8"]
}

resource "aws_lambda_function" "dontspendtoomuch" {
  function_name = "dontspendtoomuch-daily"

  s3_bucket = aws_s3_bucket.deployables.id
  s3_key = data.aws_s3_bucket_object.script.key
  s3_object_version = data.aws_s3_bucket_object.script.version_id

  handler = "dontspendtoomuch.lambda_handler"
  runtime = "python3.8"
  layers = [aws_lambda_layer_version.dependencies.arn]

  timeout = 120 // seconds
  reserved_concurrent_executions = 1
  role = aws_iam_role.dontspendtoomuch.arn

  environment {
    variables = {
      SLACK_SECRETS_ARN = aws_secretsmanager_secret.slack_hook_url.arn
    }
  }

  tags = {
    Service = "dontspendtoomuch"
    OwnerEmail = "swnelson@uw.edu"
  }
}

resource "aws_cloudwatch_log_group" "dontspendtoomuch_daily" {
  name = "/aws/lambda/dontspendtoomuch-daily"
  retention_in_days = 14
  tags = {
    Service = "dontspendtoomuch"
    OwnerEmail = "swnelson@uw.edu"
  }
}

resource "aws_iam_role" "dontspendtoomuch" {
  name = "hopDev-dontspendtoomuch"
  permissions_boundary = "arn:aws:iam::585193511743:policy/NoIAM"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
    Service = "dontspendtoomuch"
    OwnerEmail = "swnelson@uw.edu"
  }
}

resource "aws_iam_policy" "dontspendtoomuch" {
  name = "hopDev-dontspendtoomuch"
  description = "Policy used by dontspendtoomuch, a bot which sends messages about how much we spend on AWS."
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowWritingLogs",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Sid": "AllowReadingSecretSlackURL",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "${aws_secretsmanager_secret.slack_hook_url.arn}"
    },
    {
      "Sid": "AllowReadingCostUsage",
      "Effect": "Allow",
      "Action": "ce:GetCostAndUsage",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "dontspendtoomuch" {
  role = aws_iam_role.dontspendtoomuch.name
  policy_arn = aws_iam_policy.dontspendtoomuch.arn
}

// Event scheduling
resource "aws_cloudwatch_event_rule" "daily" {
  name = "daily-at-7am-eastern"
  description = "Trigger every day at 7AM Eastern Standard Time"
  schedule_expression = "cron(0 12 * * ? *)" // 12 because this uses UTC; eastern is UTC+5
}
resource "aws_cloudwatch_event_target" "daily" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn = aws_lambda_function.dontspendtoomuch.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dontspendtoomuch.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
