# ------------------------------------------------------------------------------
# OUTPUTS PARA COMPOSICIÓN
#
# Se exponen como MAPA (entorno => valor) y no como lista, para que los módulos
# que consuman este resultado pidan lo que necesitan por nombre:
#
#   module.data_lake.bucket_arns["prod"]
#
# Con una lista habría que usar un índice posicional, que se rompe en silencio
# apenas alguien agrega o reordena un entorno.
# ------------------------------------------------------------------------------

output "bucket_arns" {
  value       = { for env, bucket in aws_s3_bucket.data_lake : env => bucket.arn }
  description = "Mapa entorno => ARN del bucket. Lo consume el equipo de Streaming para las políticas IAM de Kinesis Firehose"
}

output "bucket_ids" {
  value       = { for env, bucket in aws_s3_bucket.data_lake : env => bucket.id }
  description = "Mapa entorno => nombre del bucket. Útil para configurar destinos y rutas de entrega"
}
