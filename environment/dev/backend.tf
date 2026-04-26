terraform {
  backend "s3" {
    bucket       = "techcorp-terraform-state-2024"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = false
    encrypt      = false
  }
}