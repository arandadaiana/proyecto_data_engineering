variable "project_prefix" {
  type        = string
  description = "Prefijo del proyecto o dominio de datos. Forma la primera parte del nombre de cada bucket"

  validation {
    # S3 solo admite minúsculas, números y guiones en el nombre del bucket.
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_prefix))
    error_message = "El prefijo solo puede tener minúsculas, números y guiones, y no puede empezar ni terminar con guión."
  }
}

variable "environments" {
  type = map(object({
    versioning_enabled = bool
  }))
  description = <<-EOT
    Entornos a crear, uno por entrada del mapa.

    La clave es el nombre del entorno (dev, staging, prod) y cumple dos funciones:
    forma parte del nombre del bucket y es el identificador estable que Terraform
    usa en el state. Por eso es un map y no una lista: renombrar o reordenar una
    lista provocaría destruir y recrear buckets que no cambiaron.

    Ejemplo:
      environments = {
        dev  = { versioning_enabled = false }
        prod = { versioning_enabled = true }
      }
  EOT

  validation {
    condition     = length(var.environments) > 0
    error_message = "Hay que declarar al menos un entorno."
  }
}
