provider "aws" {
  region = "us-west-2"
  allowed_account_ids = ["585193511743"]
}

resource "aws_secretsmanager_secret" "slack_hook_url" {
  name = "dontspendtoomuch-slack-hook-url"
  description = "Webhook URL for the dontspendtoomuch Slack app"
  tags = {
    Service = "dontspendtoomuch"
    OwnerEmail = "swnelson@uw.edu"
  }
}

resource "aws_lambda_function" "dontspendtoomuch" {
  filename = "dontspendtoomuch-lambda.zip"
  function_name = "dontspendtoomuch-daily"
  handler = "dontspendtoomuch.lambda_handler"
  runtime = "python3.8"
  timeout = 120 // seconds
  reserved_concurrent_executions = 1
  role = aws_iam_role.dontspendtoomuch.arn
  source_code_hash = filebase64sha256("dontspendtoomuch-lambda.zip")

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
