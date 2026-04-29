# 1. The ARN of the Lambda Function
# Used by: Storage module (S3) to know WHICH function to trigger.
output "lambda_function_arn" {
  description = "The Amazon Resource Name (ARN) identifying your Lambda function"
  value       = aws_lambda_function.csv_processor.arn
}

# 2. The Name of the Lambda Function
# Used by: CloudWatch or for CLI commands/testing.
output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.csv_processor.function_name
}

# 3. The Lambda Permission ID
# Used by: Storage module to create an "implicit dependency."
# This ensures permissions exist BEFORE S3 tries to set up the notification.
output "lambda_permission_id" {
  description = "The ID of the Lambda permission allowing S3 invocation"
  value       = aws_lambda_permission.allow_s3_bucket.id
}

# 4. The IAM Role ARN
# Used by: Debugging or if you need to attach more policies later.
output "lambda_iam_role_arn" {
  description = "The ARN of the IAM role used by the Lambda"
  value       = aws_iam_role.lambda_role.arn
}

# 5. The Source Code Hash
# Used by: Tracking if the code changed during deployment.
output "lambda_source_code_hash" {
  description = "Base64-encoded representation of the source code zip file"
  value       = aws_lambda_function.csv_processor.source_code_hash
}