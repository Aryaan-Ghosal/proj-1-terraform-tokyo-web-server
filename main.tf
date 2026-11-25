data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "terraform-tokyo-vpc" }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "terraform-tokyo-public-subnet" }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "terraform-tokyo-igw" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "terraform-tokyo-public-rt" }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_security_group" "web_sg" {
  name        = "terraform-tokyo-web-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP"
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
  tags = { Name = "terraform-tokyo-web-sg" }
}
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true
  user_data                   = <<-EOF_USERDATA
   #!/bin/bash
   set -eux
   apt-get update -y
   DEBIAN_FRONTEND=noninteractive apt-get install -y apache2
   systemctl enable apache2
   systemctl start apache2
   echo "<h1>Terraform Web Server - Tokyo</h1>" > /var/www/html/index.html
 EOF_USERDATA
  tags                        = { Name = "terraform-tokyo-web-server" }
}
output "vpc_id" {
  value = aws_vpc.main.id
}
output "instance_id" {
  value = aws_instance.web_server.id
}
output "public_ip" {
  value = aws_instance.web_server.public_ip
}
output "website_url" {
  value = "http://${aws_instance.web_server.public_ip}"
}
