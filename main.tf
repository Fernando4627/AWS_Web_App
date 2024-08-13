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

resource "aws_default_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terra_Test_VPC"
    Env = "TestTerraAWS"
  }
}
import {
  to = aws_default_vpc.app_vpc
  id = "vpc-a01106c2"
}
resource "aws_subnet" "subnet" {
  count = 2
  vpc_id = aws_vpc.app_vpc.id
  cidr_block = cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-${count.index}"
    Env = "TestTerraAWS"
  }
}

resource "aws_ecs_cluster" "app_clust" {
  name = "app-cluster"
  tags = {
    Env = "TestTerraAWS"
  }
}

resource "aws_instance" "app_server" {
  ami           = var.ubuntu
  instance_type = "t2.micro"
  count=2
  tags = {
    Name = element(var.ubu_name_list, count.index)
    Env  = "TestTerraAWS"
  }
}
resource "aws_s3_bucket" "app_storage" {
  bucket = "my-tf-test-bucket"

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
