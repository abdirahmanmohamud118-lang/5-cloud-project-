variable "environment" {
  type = string
  default = "dev"

  validation {
    condition = contains(["dev", "stage", "prod"], var.environment)
    error_message = "the environement could only be dev , stage , prod"
  }
}

variable "project_name" {
  type = string
  default = "serverless-architect-dev-project"
}

