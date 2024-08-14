resource "aws_vpc" "app_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "app_vpc"   
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

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
  }
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh"
  }
}

resource "aws_subnet" "app_vpc_subnet" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "app_vpc_subnet"
  }
}

resource "aws_ecs_cluster" "app_clust" {
  name = "app-cluster"
}

resource "aws_instance" "app_server" {
  ami = var.aws_linux
  instance_type = "t2.micro"
  count=2
  user_data = file("scripts/user_data.sh")
  user_data_replace_on_change = true
  subnet_id = aws_subnet.app_vpc_subnet.id
  vpc_security_group_ids= [aws_security_group.allow_http.id]
  tags = {
    Name = element(var.awsl_name_list, count.index)
  }
}
resource "aws_s3_bucket" "app_storage" {
  bucket = "terra1234bucket1234-test"

  tags = {
    Name = "Terra_Test_S3_1"
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
