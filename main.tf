terraform {
  #required_providers {
  #  jenkins = {
  #    source = "taiidani/jenkins"
  #    version = "0.9.2"
  #  }
  #}
 
  backend "s3" {
    bucket = var.s3_bucket
    key = var.s3_key
    region = "us-west-2"
  }

  required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "4.19.0"
      }
    }

  resource "aws_iam_user_policy" "jenkins_user_policy" {
    name = "test"
    user = aws_iam_user.lb.name

    # Terraform's "jsonencode" function converts a
    # Terraform expression result to valid JSON syntax.
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ec2:*",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
              {
          Action = [
            "s3:*",
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }

  resource "aws_iam_user" "jenkins" {
    name = "jenkins"
    path = "/"
  }

  resource "aws_iam_access_key" "jenkins_user_access_key" {
    user = aws_iam_user.jenkins.name
  }
    
  resource "aws_security_group" "jenkins_sg" {
    name        = "jenkins_sg"
    description = "Allow Jenkins Traffic"
    vpc_id      = var.vpc_id

    ingress {
      description      = "Allow from Personal CIDR block"
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      cidr_blocks      = [var.cidr_block]
    }

    ingress {
      description      = "Allow SSH from Personal CIDR block"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = [var.cidr_block]
    }

    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    tags = {
      Name = "Jenkins SG"
    }

  }

  resource "aws_instance" "web" {
    ami             = data.aws_ami.amazon_linux.id
    instance_type   = "t2.micro"
    key_name        = var.key_name
    security_groups = [aws_security_group.jenkins_sg.name]
    user_data       = "${file("install_jenkins.sh")}"
    tags = {
      Name = "Jenkins"
    }
  }

  data "aws_ami" "amazon_linux" {
    most_recent = true

    filter {
      name   = "name"
      values = ["amzn2-ami-hvm-2.0*"]
    }

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }

    filter {
      name   = "root-device-type"
      values = ["ebs"]
    }

    owners = ["amazon"] # Canonical
  }

}