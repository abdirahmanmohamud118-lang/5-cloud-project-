module "vpc" {
  source = "./module/networking"
  vpc_config = {
    cidr_block = "10.0.0.0/16"
    name       = "module_vpc"
  }
  subnet_config = {
    subnet_1 = {
      cidr_block = "10.0.0.0/24"
      az         = "us-east-1a"
    }

      subnet_2 = {
      cidr_block = "10.0.1.0/24"
      az         = "us-west-1b"
    }
  }
}

git remote add origin https://github.com/abdirahmanmohamud118-lang/5-cloud-project-.git