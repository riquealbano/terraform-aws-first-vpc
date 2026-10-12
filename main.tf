terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

variable "meu_ip" {
  description = "Meu IP público em CIDR, ex: 203.0.113.10/32"
  type        = string
}

resource "aws_vpc" "minha_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "minha-primeira-vpc"
  }
}

resource "aws_subnet" "subnet_publica" {
  vpc_id            = aws_vpc.minha_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "sa-east-1a"

  tags = {
    Name = "subnet-publica"
  }
}

resource "aws_subnet" "subnet_privada" {
  vpc_id            = aws_vpc.minha_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "sa-east-1a"

  tags = {
    Name = "subnet-privada"
  }
}

resource "aws_internet_gateway" "meu_igw" {
  vpc_id = aws_vpc.minha_vpc.id

  tags = {
    Name = "meu-igw"
  }
}

resource "aws_route_table" "rota_publica" {
  vpc_id = aws_vpc.minha_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.meu_igw.id
  }

  tags = {
    Name = "rota-publica"
  }
}

resource "aws_route_table_association" "associacao_publica" {
  subnet_id      = aws_subnet.subnet_publica.id
  route_table_id = aws_route_table.rota_publica.id
}

resource "aws_security_group" "grupo-publico" {
  name        = "grupo-publico"
  description = "Permite SSH apenas do meu IP"
  vpc_id      = aws_vpc.minha_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.meu_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grupo-publico"
  }
}

resource "aws_key_pair" "minha_chave" {
  key_name   = "minha-ec2-key"
  public_key = file("~/.ssh/minha-ec2-key.pub")
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "minha_ec2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subnet_publica.id
  vpc_security_group_ids      = [aws_security_group.grupo-publico.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.minha_chave.key_name

  tags = {
    Name = "minha-primeira-ec2"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

output "ip_publico" {
  value = aws_instance.minha_ec2.public_ip
}

output "comando_ssh" {
  value = "ssh -i ~/.ssh/minha-ec2-key ec2-user@${aws_instance.minha_ec2.public_ip}"
}