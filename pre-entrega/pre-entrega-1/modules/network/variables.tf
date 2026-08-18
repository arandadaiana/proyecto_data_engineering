variable "environment" {
  type        = string
  description = "Identificador del entorno (dev, staging, prod). Se propaga al nombre y a las etiquetas de cada recurso de red"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "El entorno solo admite minusculas, numeros y guiones."
  }
}

variable "aws_region" {
  type        = string
  description = "Region de AWS. Se usa para construir el service_name del Gateway Endpoint de S3, que es distinto en cada region"
}

variable "vpc_cidr" {
  type        = string
  description = "Rango CIDR de la VPC. Debe contener a todos los rangos de private_subnet_cidrs"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un bloque CIDR valido, por ejemplo 10.0.0.0/16."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Rangos CIDR de las subredes privadas, uno por zona de disponibilidad. Determina cuantas subredes se crean"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "Se requieren al menos dos subredes privadas para garantizar alta disponibilidad."
  }

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Todos los elementos deben ser bloques CIDR validos."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Zonas de disponibilidad a usar. Si se deja vacio, el modulo descubre las disponibles en la region: evita hardcodear nombres de AZ y hace el modulo portable"
  default     = []
}
