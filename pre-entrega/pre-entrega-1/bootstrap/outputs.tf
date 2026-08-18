# ------------------------------------------------------------------------------
# Estos valores son los que hay que reflejar en environments/dev/backend.tf.
# Terraform no admite variables dentro del bloque backend, asi que la unica forma
# de mantenerlos sincronizados es copiarlos desde aca.
# ------------------------------------------------------------------------------

output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.bucket
  description = "Nombre del bucket S3 a declarar como backend remoto"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.tf_locks.name
  description = "Nombre de la tabla DynamoDB a declarar para el state locking"
}

output "backend_config" {
  description = "Bloque backend listo para pegar en environments/dev/backend.tf"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tf_state.bucket}"
      key            = "dev/infraestructura-base.tfstate"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.tf_locks.name}"
      encrypt        = true
    }
  EOT
}
