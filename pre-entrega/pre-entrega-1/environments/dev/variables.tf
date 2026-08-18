variable "aws_region" {
  type        = string
  description = "Region de AWS donde se despliega el entorno. Debe coincidir con la region declarada en el backend de backend.tf"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Identificador del entorno. Se propaga a los nombres de recursos y a las etiquetas de todos ellos"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El entorno debe ser dev, staging o prod."
  }
}

variable "project_prefix" {
  type        = string
  description = "Prefijo del proyecto. Forma la primera parte del nombre del bucket del Lakehouse"
  default     = "lakehouse-raw"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_prefix))
    error_message = "Solo minusculas, numeros y guiones; no puede empezar ni terminar con guion."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "Rango CIDR de la VPC. Debe contener a todas las subredes privadas"
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Rangos CIDR de las subredes privadas, una por zona de disponibilidad"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Zonas de disponibilidad a utilizar. Vacio significa descubrirlas automaticamente en la region, lo que evita hardcodear nombres de AZ"
  default     = []
}

variable "data_prefix" {
  type        = string
  description = "Prefijo del Lakehouse sobre el que el rol de procesamiento puede leer y escribir"
  default     = "raw/"
}

variable "raw_bucket_force_destroy" {
  type        = bool
  description = "Permite destruir el bucket de datos aunque contenga objetos. Solo para entornos de practica: en produccion debe ser false"
  default     = true
}
