terraform {
required_version = ">= 1.5.0"
required_providers {
aws = {
source = "hashicorp/aws"
version = "~> 5.0"
}
}
# Configuración del Backend Remoto S3 + DynamoDB
# Mismo bucket y tabla que dev: lo que aísla los ambientes es la 'key',
# que apunta a un archivo de estado distinto dentro del bucket.
backend "s3" {
bucket = "coderhouse-terraform-2026-dev"
key = "staging/infrastructure-base.tfstate"
region = "us-east-1"
dynamodb_table = "terraform-locks-dev"
encrypt = true
}
}
provider "aws" {
region = var.aws_region
}
