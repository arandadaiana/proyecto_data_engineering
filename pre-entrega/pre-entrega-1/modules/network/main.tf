terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# DESCUBRIMIENTO DE ZONAS DE DISPONIBILIDAD
# Si el llamador no fija availability_zones, se consultan las disponibles en la
# region. Asi el modulo no hardcodea nombres de AZ y funciona en cualquier region.
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names, 0, length(var.private_subnet_cidrs)
  )

  # Mapa AZ => CIDR. Se recorre con for_each para que cada subred quede
  # direccionada por el nombre de su AZ y no por un indice posicional:
  # asi, agregar una AZ nueva no desplaza ni recrea las existentes.
  private_subnets = zipmap(local.azs, var.private_subnet_cidrs)
}

# ------------------------------------------------------------------------------
# 1. VPC
# ------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-datos-${var.environment}"
  }

  lifecycle {
    precondition {
      condition     = length(local.azs) == length(var.private_subnet_cidrs)
      error_message = "La cantidad de availability_zones debe coincidir con la de private_subnet_cidrs."
    }
  }
}

# ------------------------------------------------------------------------------
# 2. SECURITY GROUP POR DEFECTO SIN REGLAS
# AWS crea un SG por defecto que permite todo el trafico entre sus miembros. Al
# declararlo sin reglas queda vacio, de modo que ningun recurso lo herede abierto.
# ------------------------------------------------------------------------------
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "sg-default-bloqueado-${var.environment}"
  }
}

# ------------------------------------------------------------------------------
# 3. SUBREDES PRIVADAS
# Sin map_public_ip_on_launch: ninguna instancia recibe IP publica.
# ------------------------------------------------------------------------------
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name  = "subnet-privada-${var.environment}-${each.key}"
    Layer = "PrivateData"
  }
}

# ------------------------------------------------------------------------------
# 4. TABLA DE RUTEO PRIVADA
# No se define ninguna ruta hacia un Internet Gateway ni hacia un NAT Gateway:
# las subredes quedan sin salida a internet por construccion, no por omision.
# ------------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "rt-privada-${var.environment}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# 5. GATEWAY ENDPOINT DE S3
# Permite que los consumidores de streaming escriban en el Lakehouse sin salir a
# internet: el trafico viaja por la red interna de AWS. Un endpoint de tipo
# Gateway no tiene costo por hora ni por GB, a diferencia de los de tipo
# Interface, y evita por completo la necesidad de un NAT Gateway.
#
# La asociacion con la route table privada es lo que hace efectivo el endpoint:
# sin ella, el endpoint existe pero ninguna subred lo usa.
# ------------------------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "vpce-s3-gateway-${var.environment}"
  }
}
