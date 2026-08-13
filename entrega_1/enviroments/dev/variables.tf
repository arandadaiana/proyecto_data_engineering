variable "aws_region" {
type = string
description = "Region de AWS donde se despliega el ambiente. Debe coincidir con la region declarada en el backend s3 de provider.tf"
default = "us-east-1"
}
variable "environment" {
type = string
description = "Identificador del ambiente. Se propaga a los nombres de recursos (bucket RAW, rol IAM, VPC) y a la etiqueta Environment de todos los tags"
default = "dev"
}
variable "vpc_cidr" {
type = string
description = "Rango de direcciones IP de la VPC en notacion CIDR. Debe contener a todos los rangos de private_subnet_cidrs"
default = "10.0.0.0/16"
}
variable "private_subnet_cidrs" {
type = list(string)
description = "Rangos CIDR de las subredes privadas, uno por cada AZ. Debe tener la misma cantidad de elementos que availability_zones"
default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "availability_zones" {
type = list(string)
description = "Zonas de disponibilidad donde se crean las subredes privadas. Deben pertenecer a la region indicada en aws_region"
default = ["us-east-1a", "us-east-1b"]
}
variable "raw_bucket_force_destroy" {
type = bool
description = "Si es true, permite destruir el bucket RAW aunque contenga objetos. Solo apto para ambientes de practica: en produccion debe ser false para evitar borrados accidentales"
default = true
}
