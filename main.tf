provider "aws" {
  region = "us-east-1"
}

##########################
# DynamoDB Table
##########################
resource "aws_dynamodb_table" "users" {
  name           = "UsersTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment = "dev"
  }
}

##########################
# IAM Role for Lambda
##########################
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sns" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

##########################
# Lambda Functions (CRUD)
##########################
locals {
  lambda_functions = ["create_user", "get_user", "update_user", "delete_user", "slack_alert"]
}

resource "aws_lambda_function" "user_lambdas" {
  for_each      = toset(local.lambda_functions)
  function_name = "${each.key}Lambda"
  handler       = "${each.key}.lambda_handler"
  runtime       = "python3.11"
  filename      = "${path.module}/lambda/${each.key}.zip"
  role          = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME        = aws_dynamodb_table.users.name
      SLACK_WEBHOOK_URL = var.slack_webhook
    }
  }
}

##########################
# Lambda Aliases (Fixed)
##########################
# Removed invalid routing_config
resource "aws_lambda_alias" "prod_alias" {
  for_each         = toset(["create_user", "get_user", "update_user", "delete_user"])
  name             = "prod"
  function_name    = aws_lambda_function.user_lambdas[each.key].function_name
  function_version = "$LATEST"
}

##########################
# API Gateway HTTP API
##########################
resource "aws_apigatewayv2_api" "user_api" {
  name          = "user-management-api"
  protocol_type = "HTTP"
}

# Integrations
resource "aws_apigatewayv2_integration" "user_integrations" {
  for_each               = toset(["create_user", "get_user", "update_user", "delete_user"])
  api_id                 = aws_apigatewayv2_api.user_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.user_lambdas[each.key].arn
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "user_routes" {
  for_each = {
    create_user = "POST /users"
    get_user    = "GET /users/{id}"
    update_user = "PUT /users/{id}"
    delete_user = "DELETE /users/{id}"
  }

  api_id    = aws_apigatewayv2_api.user_api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.user_integrations[each.key].id}"
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "apigw_invoke" {
  for_each        = toset(["create_user", "get_user", "update_user", "delete_user"])
  statement_id    = "AllowAPIGatewayInvoke-${each.key}"
  action          = "lambda:InvokeFunction"
  function_name   = aws_lambda_function.user_lambdas[each.key].function_name
  principal       = "apigateway.amazonaws.com"
}

##########################
# CloudWatch Logs & Alarms
##########################
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/dev"
  retention_in_days = 14
}

resource "aws_sns_topic" "slack_notifications" {
  name = "slack_notifications"
}

resource "aws_cloudwatch_metric_alarm" "lambda_5xx" {
  alarm_name          = "lambda_5xx_alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = [aws_sns_topic.slack_notifications.arn]
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.slack_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.user_lambdas["slack_alert"].arn
}



