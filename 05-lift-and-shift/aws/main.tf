############################################################
# Lift-and-Shift: se crea en AWS un servidor Ubuntu + Nginx
# igual al de origen y se le copia la aplicación sin cambios.
############################################################

variable "package_url" {
  description = "URL prefirmada del paquete migration-package.tar.gz en S3"
  type        = string
  sensitive   = true
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "web" {
  name        = "lift-shift-web"
  description = "HTTP para la aplicacion migrada"
  vpc_id      = data.aws_vpc.default.id

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
}

resource "aws_instance" "migrado" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    exec > /var/log/lift-and-shift.log 2>&1
    apt-get update
    apt-get install -y nginx curl
    rm -f /etc/nginx/sites-enabled/default
    curl -fsSL "${var.package_url}" -o /tmp/migration-package.tar.gz
    tar -xzf /tmp/migration-package.tar.gz -C /
    systemctl restart nginx
  EOT

  tags = { Name = "servidor-migrado" }
}

output "url_aplicacion" {
  value = "http://${aws_instance.migrado.public_ip}"
}

output "ip_publica" {
  value = aws_instance.migrado.public_ip
}
