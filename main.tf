data "aws_vpc" "app_vpc" {
  cidr_block = "172.31.0.0/16"
  tags = {
    Name = "app_vpc"
    Env = "TestTerraAWS"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
    Env = "TestTerraAWS"
  }
}

resource "aws_subnet" "app_vpc_subnet" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "172.31.1.0/24"

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
