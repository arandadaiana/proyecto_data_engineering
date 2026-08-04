# 0. Identidad de la cuenta AWS en uso
# Consulta el Account ID real en tiempo de ejecución, sin hardcodearlo.
data "aws_caller_identity" "current" {}
# 1. Invocación del Módulo de Red Base
module "network" {
source = "./modules/network"
environment = var.environment
vpc_cidr = var.vpc_cidr
}
# 2. Bucket S3 para Data Lake (Capa RAW)
resource "aws_s3_bucket" "raw_bucket" {
bucket = "datalake-raw-${var.environment}-${data.aws_caller_identity.current.account_id}"
force_destroy = true
tags = {
Name = "Data Lake Raw Bucket"
Environment = var.environment
ManagedBy = "Terraform"
}
}
# 3. Invocación del Módulo IAM Acotado
module "identity" {
source = "./modules/identity"
environment = var.environment
bucket_arn = aws_s3_bucket.raw_bucket.arn
prefix = "raw-data/*"
}