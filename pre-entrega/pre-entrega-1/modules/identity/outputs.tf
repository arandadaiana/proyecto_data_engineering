output "data_processing_role_arn" {
  value       = aws_iam_role.data_processing.arn
  description = "ARN del rol de ejecucion. Es el valor que consumira el modulo de streaming de la proxima pre-entrega para asociarlo a Lambda o Flink"
}

output "data_processing_role_name" {
  value       = aws_iam_role.data_processing.name
  description = "Nombre del rol de ejecucion"
}

output "audit_role_arn" {
  value       = aws_iam_role.audit.arn
  description = "ARN del rol de auditoria de solo lectura"
}

output "audit_role_name" {
  value       = aws_iam_role.audit.name
  description = "Nombre del rol de auditoria"
}

output "processing_policy_arn" {
  value       = aws_iam_policy.processing.arn
  description = "ARN de la politica acotada del rol de procesamiento"
}

output "processing_allowed_objects_arn" {
  value       = local.objects_arn
  description = "ARN exacto sobre el que el rol de procesamiento puede operar objetos. Se expone para poder verificarlo en revisiones de seguridad"
}
