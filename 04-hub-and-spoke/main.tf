############################################################
# Hub-and-Spoke con AWS Transit Gateway
#   hub     : servicios compartidos (10.0.0.0/16)
#   spoke_a : aplicación A          (10.1.0.0/16)
#   spoke_b : aplicación B          (10.2.0.0/16)
# Regla: los spokes hablan con el hub, pero NO entre sí.
############################################################

locals {
  vpcs = {
    hub     = { cidr = "10.0.0.0/16", subnet = "10.0.1.0/24", ip = "10.0.1.10" }
    spoke_a = { cidr = "10.1.0.0/16", subnet = "10.1.1.0/24", ip = "10.1.1.10" }
    spoke_b = { cidr = "10.2.0.0/16", subnet = "10.2.1.0/24", ip = "10.2.1.10" }
  }
  spokes = { for k, v in local.vpcs : k => v if k != "hub" }
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

# ---------- Redes (VPC) ----------
resource "aws_vpc" "this" {
  for_each             = local.vpcs
  cidr_block           = each.value.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "lab-${each.key}" }
}

resource "aws_internet_gateway" "this" {
  for_each = local.vpcs
  vpc_id   = aws_vpc.this[each.key].id
  tags     = { Name = "lab-${each.key}-igw" }
}

resource "aws_subnet" "this" {
  for_each                = local.vpcs
  vpc_id                  = aws_vpc.this[each.key].id
  cidr_block              = each.value.subnet
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-${each.key}-subnet" }
}

resource "aws_route_table" "this" {
  for_each = local.vpcs
  vpc_id   = aws_vpc.this[each.key].id
  tags     = { Name = "lab-${each.key}-rt" }
}

resource "aws_route_table_association" "this" {
  for_each       = local.vpcs
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

# Salida a Internet (solo para poder abrir la página de prueba)
resource "aws_route" "internet" {
  for_each               = local.vpcs
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[each.key].id
}

# ---------- Transit Gateway ----------
resource "aws_ec2_transit_gateway" "this" {
  description                     = "lab hub-and-spoke"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = { Name = "lab-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each           = local.vpcs
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.this[each.key].id
  subnet_ids         = [aws_subnet.this[each.key].id]
  tags               = { Name = "lab-${each.key}-attach" }
}

# Dos tablas de rutas en el TGW: una para el hub y otra para los spokes
resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "lab-tgw-rt-hub" }
}

resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "lab-tgw-rt-spokes" }
}

# Asociaciones: de qué tabla lee cada conexión
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this["hub"].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spokes" {
  for_each                       = local.spokes
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# Propagaciones: qué rutas aprende cada tabla
# - la tabla del hub conoce a los dos spokes
# - la tabla de los spokes conoce SOLO al hub (por eso A y B no se ven)
resource "aws_ec2_transit_gateway_route_table_propagation" "spokes_to_hub_rt" {
  for_each                       = local.spokes
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hub_to_spokes_rt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this["hub"].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# ---------- Rutas dentro de cada VPC hacia el TGW ----------
resource "aws_route" "hub_to_spokes" {
  for_each               = local.spokes
  route_table_id         = aws_route_table.this["hub"].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_route" "spokes_to_hub" {
  for_each               = local.spokes
  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = local.vpcs["hub"].cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ---------- Servidores de prueba ----------
resource "aws_security_group" "this" {
  for_each    = local.vpcs
  name        = "lab-${each.key}-sg"
  description = "ICMP interno y HTTP para la pagina de prueba"
  vpc_id      = aws_vpc.this[each.key].id

  ingress {
    description = "ping desde las redes del laboratorio"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    description = "pagina de prueba"
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
  tags = { Name = "lab-${each.key}-sg" }
}

resource "aws_instance" "this" {
  for_each               = local.vpcs
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.this[each.key].id
  private_ip             = each.value.ip
  vpc_security_group_ids = [aws_security_group.this[each.key].id]

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    name    = each.key
    self_ip = each.value.ip
    targets = join(" ", [for k, v in local.vpcs : v.ip if k != each.key])
  })

  tags       = { Name = "lab-${each.key}" }
  depends_on = [aws_route.internet]
}
