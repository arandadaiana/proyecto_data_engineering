provider "aws" {
  region = var.aws_region

  # default_tags aplica estas etiquetas a TODO recurso que las soporte, sin
  # repetirlas en cada bloque. Environment permite filtrar costos por entorno en
  # Cost Explorer y ManagedBy distingue lo gestionado por codigo de lo creado a
  # mano por consola.
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Proyecto    = "plataforma-datos"
    }
  }
}
