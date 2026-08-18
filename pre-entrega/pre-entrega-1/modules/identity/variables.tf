variable "environment" {
  type        = string
  description = "Identificador del entorno. Se propaga al nombre de los roles y politicas"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "El entorno solo admite minusculas, numeros y guiones."
  }
}

variable "aws_region" {
  type        = string
  description = "Region de AWS. Acota el rol de auditoria mediante la condicion aws:RequestedRegion"
}

variable "data_bucket_arn" {
  type        = string
  description = "ARN del bucket sobre el que el rol de procesamiento tendra permisos acotados. Se recibe por variable para no hardcodear el ARN dentro del modulo"

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.data_bucket_arn))
    error_message = "Debe ser un ARN de bucket S3, por ejemplo arn:aws:s3:::mi-bucket."
  }
}

variable "data_prefix" {
  type        = string
  description = "Prefijo dentro del bucket sobre el que se permiten operaciones de objeto. Todo lo que quede fuera de este prefijo es inaccesible para el rol"
  default     = "raw/"

  validation {
    condition     = endswith(var.data_prefix, "/")
    error_message = "El prefijo debe terminar en barra, por ejemplo raw/."
  }
}

variable "processing_service_principals" {
  type        = list(string)
  description = "Servicios de AWS autorizados a asumir el rol de procesamiento. Por defecto Lambda y Kinesis Data Analytics (Flink), que son los consumidores previstos"
  default     = ["lambda.amazonaws.com", "kinesisanalytics.amazonaws.com"]
}

variable "audit_principal_arns" {
  type        = list(string)
  description = "ARNs de los principals habilitados a asumir el rol de auditoria. Si se deja vacio, se habilita la propia cuenta, que delega el control en sus politicas de IAM"
  default     = []
}

variable "audit_require_mfa" {
  type        = bool
  description = "Exige segundo factor para asumir el rol de auditoria. Se mantiene en true salvo que el flujo de acceso lo impida"
  default     = true
}
