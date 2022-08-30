terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "archive_file" "lambda_function_payload" {
  type             = "zip"
  source_file      = "${path.module}/lambda/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/terraform/lambda_function_payload.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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
}
resource "aws_lambda_layer_version" "beautiful_soup_layer" {
  filename            = "terraform/beautifulSoupLayer.zip"
  layer_name          = "beautifulSoupLayer"
  compatible_runtimes = ["python3.9"]
}

resource "aws_lambda_function" "scraper" {
  filename      = "terraform/lambda_function_payload.zip"
  function_name = "Scraper"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.iam_for_lambda.arn
  layers        = [aws_lambda_layer_version.beautiful_soup_layer.arn]

  source_code_hash = filebase64sha256("terraform/lambda_function_payload.zip")

  runtime = "python3.9"
}

resource "aws_cloudwatch_event_rule" "every_hour" {
  name                = "every_hour"
  description         = "Fires every hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "scraper_every_hour" {
  rule      = aws_cloudwatch_event_rule.every_hour.name
  target_id = "scraper"
  arn       = aws_lambda_function.scraper.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_scraper" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scraper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_hour.arn
}
