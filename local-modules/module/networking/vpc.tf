resource "aws_vpc" "this" {
  cidr_block = var.vpc_config.cidr_block
  tags = {
    Name = var.vpc_config.name

  }
}
data "aws_availability_zones" "available" {
    state = "available"
  
}
resource "aws_subnet" "this" {
for_each = var.subnet_config
  vpc_id     = aws_vpc.this.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.az
  tags = {
    Name = each.key
  }


  lifecycle {
    precondition {
      condition = contains(data.aws_availability_zones.available.names, each.value.az)
      error_message = <<-EOT
      the az "${each.value.az}" you provided for subnet "${each.key}" is not valid.
       the applied setup of AWS region "${data.aws_availability_zones.available.id}"
       support  the list of supported AZs : 
       "[${join(",", data.aws_availability_zones.available.names)}]"
         Please provide a valid AZ for subnet "${each.key}"

      EOT

    }
  }
}
