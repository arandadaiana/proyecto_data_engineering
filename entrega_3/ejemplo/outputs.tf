output "bucket_arns" {
  value       = module.data_lake.bucket_arns
  description = "Mapa entorno => ARN, tal como lo devuelve el modulo"
}

output "bucket_ids" {
  value       = module.data_lake.bucket_ids
  description = "Mapa entorno => nombre del bucket"
}

output "arn_de_produccion" {
  value       = module.data_lake.bucket_arns["prod"]
  description = "Ejemplo de acceso puntual al mapa: se pide el ARN por nombre de entorno"
}
