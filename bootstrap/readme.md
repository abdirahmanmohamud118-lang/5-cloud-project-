# project-cloud-company Multi-Environment AWS Platform

A production-grade AWS infrastructure built with Terraform using a combination of private and public modules. This project provisions a complete web platform across three isolated environments — dev, staging, and prod.

---

## The Problem This Solves

Most startups run their application on a single environment. This creates several critical problems:

- Developers break production when testing new features
- Environments are not identical — "works on my machine" becomes a constant problem
- Traffic spikes crash the application because scaling is manual
- One database failure takes everything down
- No audit trail of infrastructure changes

This project solves all of that by:

- Giving each environment its own isolated infrastructure and state file
- Using Auto Scaling Groups so servers heal and scale automatically
- Placing the database in a Multi-AZ setup for prod so failover is automatic
- Managing all infrastructure as code so every change is tracked in Git



## Architecture is the folliwing structure we used 


INTERNET
   ↓
Application Load Balancer (public subnets)
   ↓
Auto Scaling Group — EC2 instances (private subnets)
    ↓
RDS MySQL Database (private subnets)

S3 Bucket — static assets and file storage (standalone)


Every environment runs this exact architecture. What changes between environments is the size and configuration of each component.



## What Each Environment Gets

| Component        | Dev     | Staging     | Prod |

| EC2 instance type | t2.micro | t3.small | t3.large |
| Min servers       | 1        | 1        | 3        |
| Max servers       | 1        | 3        | 10       | 
| RDS instance      | db.t3.micro | db.t3.small | db.t3.medium |
| RDS Multi-AZ      | No       | No       | Yes       |     
| DB backup days    | 0        | 7        | 30        |
| S3 versioning     | No       | No       | Yes       |
| Deletion protection | No     | No       | Yes |
| Estimated cost/month | ~$30   ~$100     | ~$500 |

---

## Module Structure

```
01-project/
│
├── bootstrap/               # Run once manually to create state infrastructure
│   ├── main.tf
│   └── provider.tf
│
├── environments/
│   ├── dev/                 # Development environment
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   │
│   ├── staging/             # Staging environment
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   │
│   └── prod/                # Production environment
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
│
└── modules/
    └── networking/          # Private VPC module   
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```



## Modules Used

### Private Modules (built in-house)
  Module  Purpose 
 `modules/networking`  >> VPC, subnets, IGW, route tables with dynamic CIDR calculation |

### Public Registry Modules
     Module                               Version                  Purpose 

terraform-aws-modules/security-group/aws  | ~> 5.0 | Security groups for ALB, EC2, RDS |
terraform-aws-modules/alb/aws             | 10.5.0 |  Application Load Balancer |
terraform-aws-modules/autoscaling/aws     | 9.2.0  | Auto Scaling Group + Launch Template |
terraform-aws-modules/rds/aws             | 7.2.0  | RDS MySQL database |
terraform-aws-modules/s3-bucket/aws       | ~> 4.0 | S3 storage with encryption |



## Prerequisites

Before deploying any environment you need:

1. Terraform >= 1.10.0
2. AWS CLI configured with appropriate credentials
3. An AWS account with permissions to create VPC, EC2, RDS, S3, ALB, IAM resources
4. The bootstrap infrastructure deployed (S3 state bucket)

---

## Step 1 — Deploy Bootstrap Infrastructure

This only needs to be done once. It creates the S3 bucket that stores all Terraform state files.

```bash
cd bootstrap
terraform init
terraform apply
```

Type `yes` when prompted. After this completes you will have:

A) An S3 bucket for state storage with versioning and encryption
B) State locking enabled via S3 native locking



## Step 2 — Deploy Dev Environment

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

After a successful apply you will see outputs like:


alb_dns_name      = "techcorp-dev-alb-xxxx.us-east-1.elb.amazonaws.com"
rds_endpoint      = "techcorp-dev-db.xxxx.us-east-1.rds.amazonaws.com"
s3_bucket_name    = "techcorp-dev-assets-xxxx"
vpc_id            = "vpc-xxxx"
```

---

## Step 3 — Deploy Staging Environment

Copy the dev `terraform.tfvars` into the staging folder and update the values:

```bash
cd environments/staging
```

Create `terraform.tfvars` with the following content:

hcl
project_name = "{the name you prefer for you own purpose}"
environment  = "staging"

networking_config = {
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_count  = 2
  private_subnet_count = 2
  availability_zones   = ["us-east-1a", "us-east-1b"]
}

ec2_instance_config = {
  instance_type    = "t3.small"
  key_name         = ""
  min_size         = 1
  max_size         = 3
  desired_capacity = 2
}

database_config = {
  instance_class          = "db.t3.small"
  db_name                 = "techcorp"
  db_username             = "admin"
  multi_az                = false
  backup_retention_period = 7
  allocated_storage       = 20
}

enable_versioning = false
```

Then deploy:

```bash
terraform init
terraform plan
terraform apply
```

---

## Step 4 — Deploy Prod Environment

```bash
cd environments/prod


Create `terraform.tfvars` with the following content:


project_name = "techcorp"
environment  = "prod"

networking_config = {
  vpc_cidr             = "10.2.0.0/16"
  public_subnet_count  = 3
  private_subnet_count = 3
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

ec2_instance_config = {
  instance_type    = "t3.large"
  key_name         = "techcorp-prod-key"
  min_size         = 3
  max_size         = 10
  desired_capacity = 3
}

database_config = {
  instance_class          = "db.t3.medium"
  db_name                 = "techcorp"
  db_username             = "admin"
  multi_az                = true
  backup_retention_period = 30
  allocated_storage       = 20
}

enable_versioning = true
```

Then deploy:

```bash
terraform init
terraform plan
terraform apply
```

---

## Important Notes On Prod

- `multi_az = true` means RDS will have a standby in a second AZ. If the primary AZ goes down AWS automatically promotes the standby. Failover takes 60-120 seconds.
- `enable_versioning = true` means every file uploaded to S3 keeps previous versions. This protects against accidental deletion.
- `deletion_protection` is automatically enabled for prod. You cannot accidentally destroy the database.
- `min_size = 3` means prod always runs at least 3 servers across 3 AZs. If one AZ goes down the other two keep serving traffic.

---

## Why Each VPC Has A Different CIDR


dev     → 10.0.0.0/16
staging → 10.1.0.0/16
prod    → 10.2.0.0/16


Each environment uses a different CIDR block so that if you ever need to peer the VPCs for debugging or shared services the IP ranges will not conflict.

---

## Security Model

`
Internet → ALB security group (ports 80, 443 open)
ALB → EC2 security group (port 80 from ALB only)
EC2 → RDS security group (port 3306 from EC2 only)

SSH access → restricted to your IP automatically via icanhazip.com


No EC2 instance is directly accessible from the internet. All traffic flows through the load balancer. The database is only reachable from the application servers.



## State Management

Each environment has its own isolated state file:

```
s3://techcorp-terraform-state-2024/dev/terraform.tfstate
s3://techcorp-terraform-state-2024/staging/terraform.tfstate
s3://techcorp-terraform-state-2024/prod/terraform.tfstate
```

This means destroying dev never touches prod. Engineers can work on different environments simultaneously without conflicts. State locking is handled natively by S3 using Terraform 1.10+ lockfile feature — no DynamoDB required.

---

## Destroying An Environment

```bash
cd environments/dev
terraform destroy


Note: prod has deletion protection on RDS and ALB. You must first disable these before destroying prod.

---

## Trade-offs Made In This Project

**NAT Gateway not included** — Private EC2 instances cannot pull updates from the internet. This saves approximately $32/month per environment. Add a NAT Gateway if your application needs to make outbound calls.

**No HTTPS** — The ALB listener is HTTP only. Add an ACM certificate and HTTPS listener for production workloads that handle sensitive data.

**Single region** — All environments are in us-east-1. For true disaster recovery deploy prod to a second region. See Project 5 in the roadmap for multi-region setup.

**RDS password managed by AWS** — The database password is managed by AWS Secrets Manager automatically. Retrieve it from the AWS console under Secrets Manager after deployment.

---

## Lessons Learned

- Public registry modules save significant time but require careful version pinning. A version mismatch between the module and AWS provider causes hard to debug errors.
- Separating state files per environment is non-negotiable. Shared state is a single point of failure for your entire infrastructure.
- Using `cidrsubnet()` to calculate subnet CIDRs dynamically means you never hardcode IP ranges. The networking module works in any region with any CIDR.
- The `data "http" "myip"` trick automatically restricts SSH to your current IP without you needing to look it up manually.

---

## Author

Built by Abdirahman mohamud as part of a Terraform and AWS mastery program.