variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "techcorp"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod"
  }
}

variable "networking_config" {
  description = "VPC and subnet configuration"
  type = object({
    vpc_cidr             = string
    public_subnet_count  = number
    private_subnet_count = number
    availability_zones   = list(string)
  })
  default = {
    vpc_cidr             = "10.0.0.0/16"
    public_subnet_count  = 2
    private_subnet_count = 2
    availability_zones   = ["us-east-1a ,us-east-1b"]
  }
}

# variable "allowed_cidr" {
#   description = "Your IP address for SSH access in CIDR notation"
#   type        = string
#   default     = "0.0.0.0/0"
# }

variable "ec2_instance_config" {
  description = "EC2 Auto Scaling Group configuration"
  type = object({
    instance_type    = string
    key_name         = string
    min_size         = number
    max_size         = number
    desired_capacity = number
  })
  default = {
    instance_type    = "t2.micro"
    key_name         = ""
    min_size         = 1
    max_size         = 1
    desired_capacity = 1
  }
}

variable "database_config" {
  description = "RDS database configuration"
  type = object({
    instance_class          = string
    db_name                 = string
    db_username             = string
    multi_az                = bool
    backup_retention_period = number
    allocated_storage       = number
  })
  default = {
    instance_class          = "db.t3.micro"
    db_name                 = "techcorp"
    db_username             = "admin"
    multi_az                = false
    backup_retention_period = 0
    allocated_storage       = 20
  }
}

variable "enable_versioning" {
  description = "Whether to enable S3 bucket versioning"
  type        = bool
  default     = false
}