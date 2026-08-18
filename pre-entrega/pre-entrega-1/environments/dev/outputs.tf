# ------------------------------------------------------------------------------
# Estos outputs son los INPUTS de la proxima pre-entrega. Exponerlos aca evita
# que el modulo de streaming tenga que hardcodear IDs de subred o ARNs de rol.
# ------------------------------------------------------------------------------

output "vpc_id" {
  value       = module.network.vpc_id
  description = "ID de la VPC de datos"
}

output "private_subnet_ids" {
  value       = module.network.private_subnet_ids
  description = "IDs de las subredes privadas, para desplegar en ellas los consumidores de streaming"
}

output "private_subnets_by_az" {
  value       = module.network.private_subnets_by_az
  description = "Mapa zona de disponibilidad => ID de subred"
}

output "s3_gateway_endpoint_id" {
  value       = module.network.s3_gateway_endpoint_id
  description = "ID del Gateway Endpoint de S3 asociado a la tabla de ruteo privada"
}

output "data_processing_role_arn" {
  value       = module.identity.data_processing_role_arn
  description = "ARN del rol de ejecucion, para asociarlo a Lambda o Flink en la proxima pre-entrega"
}

output "audit_role_arn" {
  value       = module.identity.audit_role_arn
  description = "ARN del rol de auditoria de solo lectura"
}

output "raw_bucket_name" {
  value       = aws_s3_bucket.raw.bucket
  description = "Nombre del bucket de la capa RAW del Lakehouse"
}

output "raw_bucket_arn" {
  value       = aws_s3_bucket.raw.arn
  description = "ARN del bucket de la capa RAW"
}
