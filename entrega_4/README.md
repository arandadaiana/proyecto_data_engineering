# Entrega 4 — Matriz de Control de Acceso IAM

Diseño de permisos para una plataforma de datos en streaming sobre **Kinesis, Glue y S3**,
aplicando mínimo privilegio y separación de responsabilidades.

## Entregable

**[`Matriz_IAM_DaianaAranda.pdf`](Matriz_IAM_DaianaAranda.pdf)** — 7 páginas.

| Sección | Contenido |
|---|---|
| 1. Introducción | Alcance, arquitectura y convenciones de ARNs |
| 2. Control Plane / Data Plane | Tabla comparativa y matriz resumen de responsabilidades |
| 3. Rol de Despliegue | Trust policy con OIDC federado + tabla Acción / Recurso / Justificación |
| 4. Rol de Ejecución | Trust policy con protección de *confused deputy* + permisos de data plane |
| 5. Rol de Operador | Trust policy con MFA obligatorio + permisos de solo lectura |
| 6. Estrategia de Auditoría | Servicios de monitoreo y matriz de trazabilidad por rol |
| 7. Conclusión | Las tres barreras independientes del modelo |

## Cómo regenerar el PDF

El documento se construye por código para que sea reproducible: las correcciones se hacen en el
script y se regenera el archivo, en lugar de editar un binario a mano.

```bash
pip install reportlab
python generar_matriz_iam.py
```

## Decisiones de diseño

**Separación estricta de planos.** El rol de despliegue crea el bucket pero **no** tiene
`s3:GetObject` sobre los datos; el rol de ejecución escribe datos pero **no** puede crear ni destruir
infraestructura. Es el error más común del ejercicio y el eje del documento.

**Permisos de soporte explícitos.** Con SSE-KMS activo, `s3:PutObject` falla sin
`kms:GenerateDataKey`. La matriz los incluye y los marca como obligatorios, porque su omisión es la
causa más frecuente de un `AccessDenied` inexplicable en producción.

**`iam:PassRole` acotado por condición.** Sin `iam:PassedToService`, el pipeline podría asignar un rol
privilegiado a un recurso que él mismo controla y heredar sus permisos. Es un vector clásico de
escalada.

**Deny explícito como red de seguridad.** Cada rol cierra con un `Deny` sobre los ARNs de la cuenta de
producción. En IAM un `Deny` prevalece siempre sobre cualquier `Allow`, incluso uno agregado después
por error.

**El único comodín está justificado.** `cloudwatch:GetMetricData` usa `Resource: "*"` porque la API no
expone ARNs de métrica. Es una acción de **solo lectura**: el criterio de no usar comodines aplica a
acciones de escritura, y el documento lo explica en la propia tabla.

## Coherencia con el resto del repositorio

Los identificadores de cuenta (`111122223333` para dev, `444455556666` para producción) son los mismos
que usa el diagrama de la [entrega 2](../entrega_2/README.md), de modo que ambos documentos describen
la misma plataforma desde ángulos distintos: allí se protege el **estado** de Terraform, acá se
protege el **acceso** a los datos.
