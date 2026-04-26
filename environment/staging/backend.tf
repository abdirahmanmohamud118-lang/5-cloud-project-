terraform {
  backend "s3" {
    bucket         = "techcorp-terraform-state-2024"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "techcorp-terraform-locks"
    encrypt        = true
  }
}