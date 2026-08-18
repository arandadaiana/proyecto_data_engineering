# PLAN_OUTPUT — Checkpoint de infraestructura base

Salida de `terraform plan` del entorno `dev`, ejecutada el 18/08/2026.

## Resultado

```
Plan: 18 to add, 0 to change, 0 to destroy.
```

Sin errores y sin cambios pendientes de otro tipo: es un plan limpio sobre un entorno
todavia no desplegado, por lo que los 18 recursos aparecen como creaciones.

| Componente | Recursos |
|---|---|
| Red (`modules/network`) | VPC, 2 subredes privadas, tabla de ruteo, 2 asociaciones, Gateway Endpoint de S3, security group por defecto bloqueado |
| Identidad (`modules/identity`) | 2 roles IAM, 2 politicas, 2 asociaciones rol-politica |
| Lakehouse (`environments/dev`) | Bucket RAW, versionado, cifrado SSE, bloqueo de acceso publico |

## Verificaciones que confirma esta salida

- **Las subredes se indexan por zona de disponibilidad**, no por posicion:
  `module.network.aws_subnet.private["us-east-1a"]`. Agregar una AZ nueva no
  desplaza ni recrea las existentes.
- **Las AZ se descubrieron solas.** `availability_zones` quedo vacio y el modulo
  resolvio `us-east-1a` y `us-east-1b` consultando la region: no hay nombres de AZ
  escritos a mano.
- **El Gateway Endpoint apunta a la region correcta**, construido desde la variable:
  `service_name = "com.amazonaws.us-east-1.s3"`.
- **Los `default_tags` del provider se propagan** a todos los recursos, visible en el
  campo `tags_all` de cada uno.
- **El nombre del bucket se resuelve en ejecucion** con el Account ID consultado por
  `data.aws_caller_identity`, sin hardcodearlo.

## Condiciones de la ejecucion

Dos aclaraciones para que la salida se pueda reproducir e interpretar:

1. **El plan se capturo con state local.** El bucket del backend remoto no existia al
   momento de generarlo, y `terraform plan` requiere un backend inicializado. El codigo
   versionado en `environments/dev/backend.tf` **si** declara el backend remoto S3 con
   `encrypt = true` y locking en DynamoDB. Para reproducirlo con el backend real hay que
   desplegar antes la capa `bootstrap/`.
2. **El Account ID esta redactado** como `<ACCOUNT_ID>`. La salida original contenia el
   numero real de la cuenta AWS y este repositorio es publico.

---

## Salida completa

```text
module.network.data.aws_availability_zones.available: Reading...
data.aws_caller_identity.current: Reading...
module.identity.data.aws_caller_identity.current: Reading...
module.identity.data.aws_iam_policy_document.audit_permissions: Reading...
module.identity.data.aws_iam_policy_document.audit_permissions: Read complete after 0s [id=3479376636]
module.identity.data.aws_caller_identity.current: Read complete after 0s [id=<ACCOUNT_ID>]
module.identity.data.aws_iam_policy_document.audit_trust: Reading...
module.identity.data.aws_iam_policy_document.processing_trust: Reading...
module.identity.data.aws_iam_policy_document.audit_trust: Read complete after 0s [id=2852955171]
module.identity.data.aws_iam_policy_document.processing_trust: Read complete after 0s [id=4022753496]
data.aws_caller_identity.current: Read complete after 0s [id=<ACCOUNT_ID>]
module.network.data.aws_availability_zones.available: Read complete after 1s [id=us-east-1]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # aws_s3_bucket.raw will be created
  + resource "aws_s3_bucket" "raw" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = "lakehouse-raw-dev-<ACCOUNT_ID>"
      + bucket_domain_name          = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = true
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + tags                        = {
          + "Layer" = "Raw"
          + "Name"  = "Lakehouse capa RAW"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "Layer"       = "Raw"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "Lakehouse capa RAW"
          + "Proyecto"    = "plataforma-datos"
        }
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + cors_rule (known after apply)

      + grant (known after apply)

      + lifecycle_rule (known after apply)

      + logging (known after apply)

      + object_lock_configuration (known after apply)

      + replication_configuration (known after apply)

      + server_side_encryption_configuration (known after apply)

      + versioning (known after apply)

      + website (known after apply)
    }

  # aws_s3_bucket_public_access_block.raw will be created
  + resource "aws_s3_bucket_public_access_block" "raw" {
      + block_public_acls       = true
      + block_public_policy     = true
      + bucket                  = (known after apply)
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + restrict_public_buckets = true
    }

  # aws_s3_bucket_server_side_encryption_configuration.raw will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + rule {
          + bucket_key_enabled = true

          + apply_server_side_encryption_by_default {
              + sse_algorithm     = "AES256"
                # (1 unchanged attribute hidden)
            }
        }
    }

  # aws_s3_bucket_versioning.raw will be created
  + resource "aws_s3_bucket_versioning" "raw" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + versioning_configuration {
          + mfa_delete = (known after apply)
          + status     = "Enabled"
        }
    }

  # module.identity.data.aws_iam_policy_document.processing_permissions will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "processing_permissions" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:ListBucket",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "ListarSoloElPrefijoDeTrabajo"

          + condition {
              + test     = "StringLike"
              + values   = [
                  + "raw/*",
                ]
              + variable = "s3:prefix"
            }
        }
      + statement {
          + actions   = [
              + "s3:GetObject",
              + "s3:PutObject",
            ]
          + effect    = "Allow"
          + resources = [
              + (known after apply),
            ]
          + sid       = "OperarObjetosDelPrefijo"
        }
    }

  # module.identity.aws_iam_policy.audit will be created
  + resource "aws_iam_policy" "audit" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Lectura de configuracion del plano de control, con denegacion explicita de acceso a datos"
      + id               = (known after apply)
      + name             = "policy-plataforma-auditoria-dev"
      + name_prefix      = (known after apply)
      + path             = "/"
      + policy           = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "s3:ListAllMyBuckets",
                          + "s3:GetEncryptionConfiguration",
                          + "s3:GetBucketVersioning",
                          + "s3:GetBucketPublicAccessBlock",
                          + "s3:GetBucketPolicy",
                          + "s3:GetBucketLocation",
                          + "logs:DescribeLogGroups",
                          + "kinesis:ListStreams",
                          + "kinesis:DescribeStreamSummary",
                          + "iam:ListRoles",
                          + "iam:ListAttachedRolePolicies",
                          + "iam:GetRolePolicy",
                          + "iam:GetRole",
                          + "glue:GetTables",
                          + "glue:GetDatabases",
                          + "ec2:DescribeVpcs",
                          + "ec2:DescribeVpcEndpoints",
                          + "ec2:DescribeSubnets",
                          + "ec2:DescribeSecurityGroups",
                          + "ec2:DescribeRouteTables",
                          + "ec2:DescribeAvailabilityZones",
                          + "cloudtrail:GetTrailStatus",
                          + "cloudtrail:DescribeTrails",
                        ]
                      + Condition = {
                          + StringEquals = {
                              + "aws:RequestedRegion" = "us-east-1"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                      + Sid       = "LecturaDeConfiguracion"
                    },
                  + {
                      + Action   = [
                          + "s3:GetObjectVersion",
                          + "s3:GetObject",
                          + "kinesis:GetShardIterator",
                          + "kinesis:GetRecords",
                        ]
                      + Effect   = "Deny"
                      + Resource = "*"
                      + Sid      = "NegarLecturaDeDatos"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + policy_id        = (known after apply)
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Proyecto"    = "plataforma-datos"
        }
    }

  # module.identity.aws_iam_policy.processing will be created
  + resource "aws_iam_policy" "processing" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Permisos S3 acotados al prefijo raw/ sin comodines globales"
      + id               = (known after apply)
      + name             = "policy-s3-restricted-dev"
      + name_prefix      = (known after apply)
      + path             = "/"
      + policy           = (known after apply)
      + policy_id        = (known after apply)
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Proyecto"    = "plataforma-datos"
        }
    }

  # module.identity.aws_iam_role.audit will be created
  + resource "aws_iam_role" "audit" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Condition = {
                          + Bool = {
                              + "aws:MultiFactorAuthPresent" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Principal = {
                          + AWS = "arn:aws:iam::<ACCOUNT_ID>:root"
                        }
                      + Sid       = "PermitirAuditores"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "Rol de solo lectura para auditar la configuracion de la plataforma de datos"
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "role-plataforma-auditoria-dev"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "Name"  = "role-plataforma-auditoria-dev"
          + "Plano" = "ControlPlane"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "role-plataforma-auditoria-dev"
          + "Plano"       = "ControlPlane"
          + "Proyecto"    = "plataforma-datos"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.identity.aws_iam_role.data_processing will be created
  + resource "aws_iam_role" "data_processing" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Condition = {
                          + StringEquals = {
                              + "aws:SourceAccount" = "<ACCOUNT_ID>"
                            }
                        }
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = [
                              + "lambda.amazonaws.com",
                              + "kinesisanalytics.amazonaws.com",
                            ]
                        }
                      + Sid       = "PermitirServiciosDeProcesamiento"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "Rol de ejecucion para el procesamiento de datos de streaming hacia la capa RAW"
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "role-data-processing-dev"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags                  = {
          + "Name"  = "role-data-processing-dev"
          + "Plano" = "DataPlane"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "role-data-processing-dev"
          + "Plano"       = "DataPlane"
          + "Proyecto"    = "plataforma-datos"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.identity.aws_iam_role_policy_attachment.audit will be created
  + resource "aws_iam_role_policy_attachment" "audit" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = "role-plataforma-auditoria-dev"
    }

  # module.identity.aws_iam_role_policy_attachment.processing will be created
  + resource "aws_iam_role_policy_attachment" "processing" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = "role-data-processing-dev"
    }

  # module.network.aws_default_security_group.this will be created
  + resource "aws_default_security_group" "this" {
      + arn                    = (known after apply)
      + description            = (known after apply)
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "sg-default-bloqueado-dev"
        }
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "sg-default-bloqueado-dev"
          + "Proyecto"    = "plataforma-datos"
        }
      + vpc_id                 = (known after apply)
    }

  # module.network.aws_route_table.private will be created
  + resource "aws_route_table" "private" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = (known after apply)
      + tags             = {
          + "Name" = "rt-privada-dev"
        }
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "rt-privada-dev"
          + "Proyecto"    = "plataforma-datos"
        }
      + vpc_id           = (known after apply)
    }

  # module.network.aws_route_table_association.private["us-east-1a"] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.network.aws_route_table_association.private["us-east-1b"] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.network.aws_subnet.private["us-east-1a"] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.1.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Layer" = "PrivateData"
          + "Name"  = "subnet-privada-dev-us-east-1a"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "Layer"       = "PrivateData"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "subnet-privada-dev-us-east-1a"
          + "Proyecto"    = "plataforma-datos"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.network.aws_subnet.private["us-east-1b"] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-east-1b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.2.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Layer" = "PrivateData"
          + "Name"  = "subnet-privada-dev-us-east-1b"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "Layer"       = "PrivateData"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "subnet-privada-dev-us-east-1b"
          + "Proyecto"    = "plataforma-datos"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.network.aws_vpc.this will be created
  + resource "aws_vpc" "this" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.0.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + tags                                 = {
          + "Name" = "vpc-datos-dev"
        }
      + tags_all                             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "vpc-datos-dev"
          + "Proyecto"    = "plataforma-datos"
        }
    }

  # module.network.aws_vpc_endpoint.s3 will be created
  + resource "aws_vpc_endpoint" "s3" {
      + arn                   = (known after apply)
      + cidr_blocks           = (known after apply)
      + dns_entry             = (known after apply)
      + id                    = (known after apply)
      + ip_address_type       = (known after apply)
      + network_interface_ids = (known after apply)
      + owner_id              = (known after apply)
      + policy                = (known after apply)
      + prefix_list_id        = (known after apply)
      + private_dns_enabled   = (known after apply)
      + requester_managed     = (known after apply)
      + route_table_ids       = (known after apply)
      + security_group_ids    = (known after apply)
      + service_name          = "com.amazonaws.us-east-1.s3"
      + service_region        = (known after apply)
      + state                 = (known after apply)
      + subnet_ids            = (known after apply)
      + tags                  = {
          + "Name" = "vpce-s3-gateway-dev"
        }
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "vpce-s3-gateway-dev"
          + "Proyecto"    = "plataforma-datos"
        }
      + vpc_endpoint_type     = "Gateway"
      + vpc_id                = (known after apply)

      + dns_options (known after apply)

      + subnet_configuration (known after apply)
    }

Plan: 18 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + audit_role_arn           = (known after apply)
  + data_processing_role_arn = (known after apply)
  + private_subnet_ids       = [
      + (known after apply),
      + (known after apply),
    ]
  + private_subnets_by_az    = {
      + us-east-1a = (known after apply)
      + us-east-1b = (known after apply)
    }
  + raw_bucket_arn           = (known after apply)
  + raw_bucket_name          = "lakehouse-raw-dev-<ACCOUNT_ID>"
  + s3_gateway_endpoint_id   = (known after apply)
  + vpc_id                   = (known after apply)

─────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```
