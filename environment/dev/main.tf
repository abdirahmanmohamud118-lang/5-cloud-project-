module "processing" {
  source = "./modules/processing"

  project_name            = var.project_name
  environment             = var.environment
  dynamodb_table_id     = module.dynamodb-table.dynamodb_table_id
  dynamodb_table_arn      = module.dynamodb-table.dynamodb_table_arn
  lambda_function_arn     = module.processing.lambda_function_arn
  lambda_permission_id    = module.processing.lambda_permission_id
  s3_bucket_arn           = module.s3-bucket.s3_bucket_arn
  sns_topic_arn           = module.sns.topic_arn

}

module "s3-bucket" {
source  = "terraform-aws-modules/s3-bucket/aws"
version = "5.12.0"

  bucket = "${var.project_name}-${var.environment}-${random_id.suffix.hex}-bucket" 
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}


resource "random_id" "suffix" {
  byte_length = 4
}


resource "aws_s3_bucket_notification" "lambda_notification" {
  bucket = module.s3-bucket.s3_bucket_id
 eventbridge = true
  lambda_function {
    lambda_function_arn = module.processing.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }
}


  module "dynamodb-table" {
source  = "terraform-aws-modules/dynamodb-table/aws"
version = "5.5.0"

name = "${var.project_name}-${var.environment}-dynamodb"
  hash_key       = "order_id"
  billing_mode   = "PAY_PER_REQUEST"
  attributes = [
    { name = "order_id", type = "S" }
  ]

}

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"

  name = "${var.project_name}-${var.environment}-sqs"

  create_dlq = true
  redrive_policy = {
    
    maxReceiveCount = 5
  }
}



module "sns" {
source  = "terraform-aws-modules/sns/aws"
version = "7.1.0"

name  = "${var.project_name}-${var.environment}-alerts"
topic_policy_statements = {
    lambda_publish = {
      actions    = ["sns:Publish"]
      principals = [{
        type        = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }]
    }
  }

  subscriptions = {
    email = {
      protocol = "email"
      endpoint = "abdirahmanmohamud118@gmail.com"

    }
  }
}

