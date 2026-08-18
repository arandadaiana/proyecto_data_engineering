variable "aws_region" {
  type        = string
  description = "Region de AWS donde se crean los buckets"
  default     = "us-east-1"
}

variable "project_prefix" {
  type        = string
  description = "Prefijo del dominio de datos. Se propaga al modulo data_lake"
  default     = "datalake-ventas"
}

variable "environments" {
  type = map(object({
    versioning_enabled = bool
  }))
  description = "Entornos a crear. Se propaga tal cual al modulo data_lake"

  default = {
    dev = {
      versioning_enabled = false
    }
    staging = {
      versioning_enabled = false
    }
    prod = {
      versioning_enabled = true
    }
  }
}
