variable "region" {
  default = "es-east-1"
}

variable "slack_webhook" {
  description = "Slack webhook URL"
}

variable "table_name" {
  default = "UsersTable"
}

variable "lambda_runtime" {
  default = "python3.11"
}

