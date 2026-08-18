terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------------------------------------------------------------
# 0. IDENTIDAD DE LA CUENTA AWS
# Un data source solo consulta información existente: no crea recursos ni genera
# costo. Devuelve el Account ID real, que se usa como sufijo único del bucket.
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# 1. BUCKETS DEL DATA LAKE — UNO POR ENTORNO
#
# for_each recorre el mapa var.environments y repite este bloque una vez por
# entrada. Dentro de cada vuelta:
#   each.key   → el nombre del entorno   ("dev")
#   each.value → el objeto de ese entorno ({ versioning_enabled = false })
#
# Al recorrer un MAP, Terraform direcciona cada recurso por su clave
# (aws_s3_bucket.data_lake["dev"]) en lugar de por posición. Eso hace que
# agregar un entorno nuevo no desplace ni recree los existentes.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "data_lake" {
  for_each = var.environments

  # Los nombres de bucket son únicos a nivel MUNDIAL. El Account ID garantiza
  # unicidad sin hardcodear nada, y permite aplicar el módulo en cualquier cuenta.
  bucket = "${var.project_prefix}-${each.key}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Data Lake ${each.key}"
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# 2. VERSIONADO CONDICIONAL
#
# En AWS el versionado es una configuración que se engancha al bucket, no un
# atributo interno: por eso es un recurso aparte.
#
# aws_s3_bucket.data_lake[each.key] selecciona, del grupo de buckets creado
# arriba, el que corresponde a este mismo entorno.
#
# El operador ternario ( condición ? valor_si_true : valor_si_false ) traduce
# el booleano de la variable al estado que espera la API de S3.
#
# Se usa "Suspended" y no "Disabled" a propósito: AWS solo acepta "Disabled" en
# buckets que nunca tuvieron versionado. Una vez activado, el único camino de
# vuelta es "Suspended", así que este valor funciona en ambos casos.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = var.environments

  bucket = aws_s3_bucket.data_lake[each.key].id

  versioning_configuration {
    status = each.value.versioning_enabled ? "Enabled" : "Suspended"
  }
}
