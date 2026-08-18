output "vpc_id" {
  value       = aws_vpc.this.id
  description = "ID de la VPC creada"
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "Rango CIDR efectivo de la VPC"
}

output "private_subnet_ids" {
  value       = values(aws_subnet.private)[*].id
  description = "Lista de IDs de las subredes privadas, ordenada por zona de disponibilidad"
}

output "private_subnets_by_az" {
  value       = { for az, s in aws_subnet.private : az => s.id }
  description = "Mapa zona de disponibilidad => ID de subred. Permite al consumidor elegir una AZ concreta por nombre en lugar de por posicion"
}

output "private_route_table_id" {
  value       = aws_route_table.private.id
  description = "ID de la tabla de ruteo privada, asociada al Gateway Endpoint de S3"
}

output "s3_gateway_endpoint_id" {
  value       = aws_vpc_endpoint.s3.id
  description = "ID del Gateway Endpoint de S3"
}

output "availability_zones" {
  value       = local.azs
  description = "Zonas de disponibilidad efectivamente utilizadas"
}
