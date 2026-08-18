terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ----------------------------------------------------------------------------
  # BACKEND REMOTO S3 + DYNAMODB
  #
  # Los valores van escritos como texto literal y no como variables porque
  # Terraform NO admite interpolacion dentro del bloque backend: necesita saber
  # donde esta el state antes de evaluar cualquier expresion del codigo.
  #
  # Deben coincidir exactamente con lo que creo el bootstrap. Para obtenerlos:
  #     cd ../../bootstrap && terraform output backend_config
  #
  # encrypt = true activa el cifrado del lado del servidor sobre el objeto del
  # state, ademas del cifrado por defecto configurado en el propio bucket.
  # ----------------------------------------------------------------------------
  backend "s3" {
    bucket         = "coderhouse-tfstate-preentrega1-dev"
    key            = "dev/infraestructura-base.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks-preentrega1-dev"
    encrypt        = true
  }
}
