# 0. Identidad de la cuenta AWS en uso
# Consulta el Account ID real en tiempo de ejecución, sin hardcodearlo.
data "aws_caller_identity" "current" {}
# 1. Invocación del Módulo de Red Base
# Los módulos son compartidos por todos los ambientes: viven en la raíz del repo.
module "network" {
source = "../../modules/network"
environment = var.environment
aws_region = var.aws_region
vpc_cidr = var.vpc_cidr
private_subnet_cidrs = var.private_subnet_cidrs
availability_zones = var.availability_zones
}
# 2. Bucket S3 para Data Lake (Capa RAW)
resource "aws_s3_bucket" "raw_bucket" {
bucket = "datalake-raw-${var.environment}-${data.aws_caller_identity.current.account_id}"
force_destroy = var.raw_bucket_force_destroy
tags = {
Name = "Data Lake Raw Bucket"
Environment = var.environment
ManagedBy = "Terraform"
}
}
# 3. Invocación del Módulo IAM Acotado
module "identity" {
source = "../../modules/identity"
environment = var.environment
bucket_arn = aws_s3_bucket.raw_bucket.arn
prefix = "raw-data/*"
}
