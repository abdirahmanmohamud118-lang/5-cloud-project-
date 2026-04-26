locals {
  name        = "${var.project_name}-${var.environment}"
  environment = var.environment

  common_tags = {
    Name        = "${var.project_name}-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source               = "../../../vpc-module/module/vpc"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_count  = var.networking_config.public_subnet_count
  private_subnet_count = var.networking_config.private_subnet_count
  project_name         = var.project_name
  environment          = var.environment
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, var.networking_config.public_subnet_count)
}

module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-alb-sg"
  description = "this is the security group of the application load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
  tags                = local.common_tags
}


module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${local.name}-ec2-sg"
  description = "this is the security group of the ec2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]

  ingress_cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  ingress_rules       = ["ssh-tcp"]

  egress_rules = ["all-all"]

  tags = local.common_tags

}

module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.ec2_sg.security_group_id
    }
  ]

  egress_rules = ["all-all"]

  tags = local.common_tags
}


#PPLICATION LOAD BALANCER — public module
module "alb" {
  source                     = "terraform-aws-modules/alb/aws"
  version                    = "10.5.0"
  enable_deletion_protection = false
  name                       = "${local.name}-alb"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnet_ids

  security_groups       = [module.alb_sg.security_group_id]
  create_security_group = false

  target_groups = {
    main = {
      name              = "${local.name}-tg"
      backend_protocol  = "HTTP"
      backend_port      = 80
      target_type       = "instance"
      create_attachment = false

      health_check = {
        enabled             = true
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
      }
    }
  }

  # HTTP listener
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "main"
      }
    }
  }

  tags = local.common_tags
}


# AUTO SCALING GROUP — public module
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.2.0"

  name = "${local.name}-asg"

  # launch template settings
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.ec2_instance_config.instance_type
  key_name      = var.ec2_instance_config.key_name != "" ? var.ec2_instance_config.key_name : null

  # security group
  security_groups = [module.ec2_sg.security_group_id]

  # scaling settings
  min_size         = var.ec2_instance_config.min_size
  max_size         = var.ec2_instance_config.max_size
  desired_capacity = var.ec2_instance_config.desired_capacity

  # deploy in private subnets
  vpc_zone_identifier = module.vpc.private_subnet_ids

  # attach to ALB target group
  # CORRECT
traffic_source_attachments = {
    alb = {
      traffic_source_identifier = module.alb.target_groups["main"].arn
      traffic_source_type       = "elbv2"
    }
}

  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 20
        volume_type           = "gp3"
        delete_on_termination = true
      }
    }
  ]

  tags = local.common_tags
}


# ─────────────────────────────
# RDS DATABASE — public module
# ─────────────────────────────
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.0"

  identifier = "${local.name}-db"

  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.database_config.instance_class
  allocated_storage    = 20
  storage_encrypted    = true
  family               = "mysql8.0"
  major_engine_version = "8.0"

  db_name  = var.database_config.db_name
  username = var.database_config.db_username
  port     = 3306

  multi_az               = var.database_config.multi_az
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  backup_retention_period = var.database_config.backup_retention_period
  skip_final_snapshot     = local.environment != "prod"
  deletion_protection     = local.environment == "prod"
  db_subnet_group_name = module.vpc.db_subnet_group_name

  tags = local.common_tags
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

module "s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${local.name}-assets-${random_id.bucket_suffix.hex}"

  versioning = {
    enabled = var.enable_versioning
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}
