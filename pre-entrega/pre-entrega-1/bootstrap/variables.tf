variable "aws_region" {
  type        = string
  description = "Region donde se crean el bucket del state y la tabla de locking. Debe coincidir con la declarada en environments/dev/backend.tf"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Entorno asociado a esta infraestructura de backend"
  default     = "dev"
}

variable "state_bucket_name" {
  type        = string
  description = "Nombre del bucket del state. Los nombres de bucket son unicos a nivel mundial: si este ya esta tomado, hay que cambiarlo aca Y en environments/dev/backend.tf, porque deben coincidir exactamente"
  default     = "coderhouse-tfstate-preentrega1-dev"
}

variable "lock_table_name" {
  type        = string
  description = "Nombre de la tabla DynamoDB de locking. Tambien debe coincidir con backend.tf"
  default     = "terraform-locks-preentrega1-dev"
}

variable "force_destroy" {
  type        = bool
  description = "Permite destruir el bucket del state aunque contenga objetos. Apto solo para entornos de practica: en produccion debe ser false"
  default     = true
}
