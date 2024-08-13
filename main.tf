terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "app_server" {
  ami           = var.ubuntu
  instance_type = "t2.micro"
  tags = {
    Name = "ubu-1"
    Env  = "TestTerraAWS"
  }
}
resource "aws_instance" "app_server2" {
  ami           = var.redhat
  instance_type = "t2.micro"
  tags = {
    Name = "redh-1"
    Env  = "TestTerraAWS"
  }
}
resource "aws_instance" "app_server3" {
  ami           = var.aws_linux
  instance_type = "t2.micro"
  tags = {
    Name = "awsl-1"
    Env  = "TestTerraAWS"
  }
}
resource "aws_resourcegroups_group" "test" {
  name = "TerraGroupTest"
  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::EC2::Instance"
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