terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Esta capa usa STATE LOCAL a proposito. El backend remoto necesita un bucket
  # y una tabla que todavia no existen la primera vez que se despliega: no se
  # puede guardar el estado en un bucket que aun no fue creado. El bootstrap
  # resuelve ese arranque y se corre una sola vez.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform-Bootstrap"
      Proyecto    = "plataforma-datos"
    }
  }
}

# ------------------------------------------------------------------------------
# 1. BUCKET DEL ESTADO REMOTO
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "tf_state" {
  bucket        = var.state_bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = "Terraform State Storage"
  }
}

# El versionado permite recuperar un state corrupto volviendo a la revision
# anterior, sin reconstruir el inventario recurso por recurso.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado del lado del servidor. El state guarda en texto plano los atributos de
# todo lo gestionado, asi que cifrarlo no es opcional.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Ningun bucket de estado debe ser alcanzable desde internet.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# 2. TABLA DE LOCKING
# Evita que dos ejecuciones simultaneas escriban el mismo state y lo corrompan.
# La clave de particion LockID es un requisito del backend s3 de Terraform.
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "tf_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}
