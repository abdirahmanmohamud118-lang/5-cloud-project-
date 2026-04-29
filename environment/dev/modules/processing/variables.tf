variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev/prod)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "The ARN of the S3 bucket to grant Lambda access"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table for IAM permissions"
  type        = string
}

variable "dynamodb_table_id" {
  description = "The name of the DynamoDB table for Lambda env vars"
  type        = string
}

variable "sns_topic_arn" {
  description = "The ARN of the SNS topic for alerts"
  type        = string
}

variable "lambda_function_arn" {
  description = "The ARN of the Lambda to trigger"
  type        = string
}

variable "lambda_permission_id" {
  description = "The ID of the Lambda permission to ensure order of creation"
  type        = string
}