############################################################
# Bastion host: único punto de entrada SSH a un servidor privado
#   - subred pública : bastion (IP pública, SSH solo desde allowed_cidr)
#   - subred privada : servidor (SIN IP pública, SSH solo desde el bastion)
############################################################

variable "public_key" {
  description = "Contenido de la llave pública SSH (archivo .pub)"
  type        = string
}

variable "allowed_cidr" {
  description = "IP desde la que se permite SSH al bastion, en formato x.x.x.x/32"
  type        = string
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# ---------- Red ----------
resource "aws_vpc" "this" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "lab-bastion-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "lab-bastion-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-bastion-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "lab-bastion-private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "lab-bastion-public-rt" }
}

# La tabla de rutas privada no tiene salida a Internet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "lab-bastion-private-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ---------- Seguridad ----------
resource "aws_security_group" "bastion" {
  name        = "lab-bastion-sg"
  description = "SSH al bastion solo desde una IP autorizada"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH desde la IP autorizada"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "lab-bastion-sg" }
}

resource "aws_security_group" "private" {
  name        = "lab-private-sg"
  description = "SSH al servidor privado solo desde el bastion"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "SSH solo desde el security group del bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "lab-private-sg" }
}

# ---------- Llave y servidores ----------
resource "aws_key_pair" "this" {
  key_name   = "lab-bastion-key"
  public_key = var.public_key
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  tags                        = { Name = "bastion" }
  depends_on                  = [aws_route_table_association.public]
}

resource "aws_instance" "private" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = false
  tags                        = { Name = "servidor-privado" }
}
