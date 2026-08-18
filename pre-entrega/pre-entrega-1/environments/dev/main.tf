# ------------------------------------------------------------------------------
# 0. IDENTIDAD DE LA CUENTA
# Se consulta en tiempo de ejecucion en lugar de hardcodear el Account ID, de
# modo que el codigo funcione en cualquier cuenta sin modificaciones.
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# 1. RED BASE
# El modulo no conoce nada del entorno: todo entra por variables.
# ------------------------------------------------------------------------------
module "network" {
  source = "../../modules/network"

  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ------------------------------------------------------------------------------
# 2. BUCKET DEL LAKEHOUSE (CAPA RAW)
# Los nombres de bucket son unicos a nivel mundial: el Account ID como sufijo
# garantiza unicidad sin escribirlo a mano.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "raw" {
  bucket        = "${var.project_prefix}-${var.environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.raw_bucket_force_destroy

  tags = {
    Name  = "Lakehouse capa RAW"
    Layer = "Raw"
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# La capa RAW no debe ser alcanzable desde internet bajo ninguna circunstancia.
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# 3. IDENTIDAD
# El ARN del bucket se pasa por referencia al recurso, no como texto literal:
# si el nombre del bucket cambia, la politica se actualiza sola.
# ------------------------------------------------------------------------------
module "identity" {
  source = "../../modules/identity"

  environment     = var.environment
  aws_region      = var.aws_region
  data_bucket_arn = aws_s3_bucket.raw.arn
  data_prefix     = var.data_prefix
}
