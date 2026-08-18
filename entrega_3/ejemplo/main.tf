# ------------------------------------------------------------------------------
# EJEMPLO DE USO DEL MÓDULO data_lake
#
# Una sola invocación crea los tres entornos. Para agregar un cuarto alcanza con
# sumar una entrada al mapa environments: no hay que tocar el módulo.
# ------------------------------------------------------------------------------
module "data_lake" {
  source = "../modules/data_lake"

  project_prefix = var.project_prefix
  environments   = var.environments
}

# ------------------------------------------------------------------------------
# COMPOSICIÓN: consumir el output del módulo desde otro recurso
#
# Este es el motivo por el que bucket_arns se expone como mapa. La política pide
# el ARN de producción POR NOMBRE, sin depender del orden en que se crearon los
# buckets ni de cuántos entornos existan.
#
# El sufijo "/*" es necesario porque PutObject actúa sobre los OBJETOS del
# bucket, no sobre el bucket en sí.
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "firehose_write_prod" {
  name        = "policy-firehose-write-prod"
  description = "Permite a Kinesis Firehose escribir en la capa RAW de produccion"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FirehoseObjectWrite"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${module.data_lake.bucket_arns["prod"]}/*"]
      }
    ]
  })
}
