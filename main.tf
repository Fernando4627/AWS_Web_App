terraform{
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}


resource "aws_vpc" "app_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "app_vpc"
    Env = "TestTerraAWS"
  }
}

resource "aws_subnet" "app_vpc_subnet" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "app_vpc_subnet"
    Env = "TestTerraAWS"
  }
}

resource "aws_ecs_cluster" "app_clust" {
  name = "app-cluster"
  tags = {
    Env = "TestTerraAWS"
  }
}

data "ubu_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
    }
    filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_instance" "app_server" {
  #ami           = data.ubu_ami.ubuntu.id
  ami = var.aws_linux
  instance_type = "t2.micro"
  count=2
  user_data = filebase64("scripts/user_data.sh")
  tags = {
    Name = element(var.awsl_name_list, count.index)
    Env  = "TestTerraAWS"
  }
}
resource "aws_s3_bucket" "app_storage" {
  bucket = "terra1234bucket1234-test"

  tags = {
    Name = "Terra_Test_S3_1"
    Env  = "TestTerraAWS"
  }
}



resource "aws_resourcegroups_group" "test" {
  name = "TerraGroupTest"
  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "Env",
      "Values": ["TestTerraAWS"]
    }
  ]
}
JSON
  }
}
