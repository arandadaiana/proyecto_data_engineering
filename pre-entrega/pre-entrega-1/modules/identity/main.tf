terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  audit_principals = length(var.audit_principal_arns) > 0 ? var.audit_principal_arns : ["arn:aws:iam::${local.account_id}:root"]
  objects_arn      = "${var.data_bucket_arn}/${var.data_prefix}*"
}

# ==============================================================================
# ROL 1 - EJECUCION DE PROCESAMIENTO DE DATOS (DATA PLANE)
# Lo asumira una funcion Lambda o una aplicacion Flink sobre Kinesis Data
# Analytics para mover datos del stream al Lakehouse.
# ==============================================================================

# La condicion aws:SourceAccount evita el problema del "confused deputy": sin
# ella, el servicio podria ser inducido a asumir este rol en nombre de un
# recurso de otra cuenta.
data "aws_iam_policy_document" "processing_trust" {
  statement {
    sid     = "PermitirServiciosDeProcesamiento"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = var.processing_service_principals
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "data_processing" {
  name                 = "role-data-processing-${var.environment}"
  description          = "Rol de ejecucion para el procesamiento de datos de streaming hacia la capa RAW"
  assume_role_policy   = data.aws_iam_policy_document.processing_trust.json
  max_session_duration = 3600

  tags = {
    Name  = "role-data-processing-${var.environment}"
    Plano = "DataPlane"
  }
}

# Los permisos se separan en dos statements por como funciona S3: ListBucket es
# una accion sobre el BUCKET, mientras que GetObject y PutObject operan sobre los
# OBJETOS. Requieren ARNs de distinto nivel y no pueden ir en un mismo bloque.
data "aws_iam_policy_document" "processing_permissions" {
  statement {
    sid       = "ListarSoloElPrefijoDeTrabajo"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.data_bucket_arn]

    # Sin esta condicion, ListBucket enumeraria el bucket completo.
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.data_prefix}*"]
    }
  }

  statement {
    sid       = "OperarObjetosDelPrefijo"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = [local.objects_arn]
  }
}

resource "aws_iam_policy" "processing" {
  name        = "policy-s3-restricted-${var.environment}"
  description = "Permisos S3 acotados al prefijo ${var.data_prefix} sin comodines globales"
  policy      = data.aws_iam_policy_document.processing_permissions.json
}

resource "aws_iam_role_policy_attachment" "processing" {
  role       = aws_iam_role.data_processing.name
  policy_arn = aws_iam_policy.processing.arn
}

# ==============================================================================
# ROL 2 - AUDITORIA DEL PLANO DE CONTROL (SOLO LECTURA)
# Permite inspeccionar como esta configurada la plataforma sin poder modificarla
# ni leer los datos que contiene.
# ==============================================================================

data "aws_iam_policy_document" "audit_trust" {
  statement {
    sid     = "PermitirAuditores"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.audit_principals
    }

    dynamic "condition" {
      for_each = var.audit_require_mfa ? [1] : []

      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}

resource "aws_iam_role" "audit" {
  name                 = "role-plataforma-auditoria-${var.environment}"
  description          = "Rol de solo lectura para auditar la configuracion de la plataforma de datos"
  assume_role_policy   = data.aws_iam_policy_document.audit_trust.json
  max_session_duration = 3600

  tags = {
    Name  = "role-plataforma-auditoria-${var.environment}"
    Plano = "ControlPlane"
  }
}

data "aws_iam_policy_document" "audit_permissions" {
  # Las acciones Describe y List del plano de control NO admiten permisos a nivel
  # de recurso: la API no expone ARNs para ellas, de modo que AWS exige "*". Se
  # acepta porque son operaciones de SOLO LECTURA sobre metadatos, y se acota con
  # una condicion de region para que el rol no vea otras regiones de la cuenta.
  statement {
    sid    = "LecturaDeConfiguracion"
    effect = "Allow"

    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeAvailabilityZones",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:ListAllMyBuckets",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListStreams",
      "glue:GetDatabases",
      "glue:GetTables",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRoles",
      "iam:ListAttachedRolePolicies",
      "logs:DescribeLogGroups",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetTrailStatus",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # Barrera explicita: auditar la configuracion no habilita a leer los datos.
  # Un Deny prevalece siempre sobre cualquier Allow, incluso uno agregado
  # despues por error en otra politica adjunta al mismo rol.
  statement {
    sid    = "NegarLecturaDeDatos"
    effect = "Deny"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "audit" {
  name        = "policy-plataforma-auditoria-${var.environment}"
  description = "Lectura de configuracion del plano de control, con denegacion explicita de acceso a datos"
  policy      = data.aws_iam_policy_document.audit_permissions.json
}

resource "aws_iam_role_policy_attachment" "audit" {
  role       = aws_iam_role.audit.name
  policy_arn = aws_iam_policy.audit.arn
}
