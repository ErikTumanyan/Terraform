provider "aws" {
  access_key = "AKIA3GFHBONV2CN2PE47"
  secret_key = "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"
  region     = "eu-central-1"
  default_tags {
    tags = {
      Owner     = "ERIK TUMANYAN"
      CreatedBy = "Terraform"
    }
  }
}
terraform {
  backend "s3" {
    bucket = "terraform-new-s3-for-erik"
    key    = "prod/web-cluster/terraform.tfstate"
    region = "eu-central-1"

  }
}
data "aws_availability_zones" "available" {}
output "aws_availability_zones" {
  value = data.aws_availability_zones.available.names
}

output "aws_ami" {
  value = "ami-03aefa83246f44ef2"
}
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}
resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}
resource "aws_security_group" "WEB-Cluster" {
  name   = "allow-http,https"
  vpc_id = aws_default_vpc.default.id

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_autoscaling_group" "web" {
  name                = "foobar3-terraform-test"
  max_size            = 3
  min_size            = 2
  health_check_type   = "ELB"
  desired_capacity    = 2
  vpc_zone_identifier = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  target_group_arns   = [aws_lb_target_group.web.arn]
  launch_template {
    id      = aws_launch_template.Cluster.id
    version = aws_launch_template.Cluster.latest_version
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "Cluster" {
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = 20
    }
  }
  name                   = "Web-Cluster-template"
  image_id               = "ami-03aefa83246f44ef2"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.WEB-Cluster.id]
  user_data              = filebase64("${path.module}/user-data.sh")

}

resource "aws_lb_target_group" "web" {
  name                 = "tg-web-lb"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = aws_default_vpc.default.id
  deregistration_delay = 10
}
resource "aws_lb" "Web-lb" {
  name               = "web-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.WEB-Cluster.id]
  subnets            = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
}
resource "aws_lb_listener" "web_lb_listener" {
  load_balancer_arn = aws_lb.Web-lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
output "aws_lb_dns" {
  value = aws_lb.Web-lb.dns_name
}
