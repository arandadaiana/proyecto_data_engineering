# Pre-entrega 1 — Checkpoint de infraestructura base

Andamiaje de una plataforma de datos en AWS: **backend remoto de Terraform**, **VPC privada
con Gateway Endpoint a S3** e **identidades IAM acotadas**, listo para que las siguientes
pre-entregas monten encima los servicios de streaming.

**Región:** `us-east-1` · **Entorno:** `dev` · **Terraform:** >= 1.5.0 · **Provider AWS:** ~> 5.0

---

## Qué se crea

18 recursos, agrupados en tres bloques:

| Bloque | Recursos |
|---|---|
| **Red** (`modules/network`) | VPC, 2 subredes privadas en AZ distintas, tabla de ruteo privada, 2 asociaciones, Gateway Endpoint de S3, security group por defecto vaciado |
| **Identidad** (`modules/identity`) | Rol de ejecución + su política, rol de auditoría + su política, 2 asociaciones |
| **Lakehouse** (`environments/dev`) | Bucket de la capa RAW con versionado, cifrado SSE y bloqueo de acceso público |

Más la capa `bootstrap/`, que se despliega aparte y una sola vez: bucket del state y tabla
de locking.

---

## Requisitos previos

| Herramienta | Versión | Verificar con |
|---|---|---|
| Terraform | >= 1.5.0 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| Credenciales | Usuario IAM configurado | `aws sts get-caller-identity` |

Las credenciales se cargan con `aws configure` y quedan en `~/.aws/credentials`. **Nunca se
escriben dentro de los archivos `.tf`**: Terraform las toma del perfil del sistema.

---

## Estructura

```
pre-entrega-1/
├── bootstrap/                    # Backend de Terraform. Se corre UNA vez, con state local
│   ├── main.tf                   # Bucket del state + tabla de locking
│   ├── variables.tf
│   ├── outputs.tf                # Devuelve el bloque backend listo para copiar
│   └── terraform.tfvars.example
│
├── modules/                      # Módulos compartidos, reutilizables por cualquier entorno
│   ├── network/                  # VPC, subredes, ruteo y Gateway Endpoint
│   └── identity/                 # Roles y políticas IAM
│
├── environments/
│   └── dev/                      # Composición del entorno: llama a los módulos
│       ├── backend.tf            # Backend remoto S3 + DynamoDB
│       ├── provider.tf           # Provider AWS con default_tags
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
│
├── PLAN_OUTPUT.md                # Salida de un terraform plan exitoso
└── .gitignore
```

Los módulos viven fuera de `environments/` a propósito. Si colgaran de `dev/`, un futuro
entorno `prod` tendría que apuntar a `../dev/modules/...`, y producción pasaría a depender
de una carpeta llamada "dev". En la raíz, todos los entornos son pares que consumen la
misma librería.

---

## Despliegue

El orden importa: **el bootstrap va primero, siempre.**

### Paso 1 — Backend (una única vez)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Al terminar, pedile a Terraform el bloque de configuración ya armado:

```bash
terraform output backend_config
```

Copiá ese bloque en `environments/dev/backend.tf`. **Tiene que coincidir exactamente**, y
por eso el output existe: para no transcribirlo a mano.

> **Si el apply falla con `BucketAlreadyExists`:** los nombres de bucket son únicos en todo
> el mundo. Cambiá `state_bucket_name` en tu `terraform.tfvars` y reflejá el nuevo valor en
> `backend.tf`.

### Paso 2 — Entorno dev

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

`terraform init` debe reportar `Successfully configured the backend "s3"!`.

> `terraform.tfvars` solo se carga automáticamente desde la carpeta **donde ejecutás el
> comando**. Un `.tfvars` en la raíz del repositorio nunca se lee.

### Consultar los resultados

```bash
terraform output
```

| Output | Para qué sirve |
|---|---|
| `vpc_id` | ID de la VPC |
| `private_subnet_ids` | Lista de subredes privadas |
| `private_subnets_by_az` | Mapa AZ => subred, para elegir una zona por nombre |
| `s3_gateway_endpoint_id` | ID del Gateway Endpoint |
| `data_processing_role_arn` | Rol a asociar a Lambda o Flink en la próxima pre-entrega |
| `audit_role_arn` | Rol de auditoría de solo lectura |
| `raw_bucket_name` / `raw_bucket_arn` | Bucket de la capa RAW |

Estos outputs son los **inputs de la pre-entrega 2**. Existen para que el módulo de streaming
no tenga que hardcodear IDs de subred ni ARNs de rol.

---

## Decisiones de diseño

### 1. Bootstrap separado con state local

El backend remoto necesita un bucket y una tabla **que todavía no existen** la primera vez.
No se puede guardar el estado en un bucket que aún no fue creado. La carpeta `bootstrap/` se
despliega con state local y su única responsabilidad es crear esa infraestructura.

### 2. El backend va escrito literal, no con variables

Terraform **no admite interpolación dentro del bloque `backend`**: necesita saber dónde está
el state antes de evaluar cualquier expresión. Por eso los nombres están como texto en
`backend.tf`, y por eso el bootstrap expone el output `backend_config`.

### 3. Subredes indexadas por AZ, no por posición

El módulo construye un mapa `AZ => CIDR` y lo recorre con `for_each`:

```hcl
module.network.aws_subnet.private["us-east-1a"]
```

Si se usara `count` sobre una lista, las subredes quedarían direccionadas por índice
(`[0]`, `[1]`). Insertar una AZ en el medio correría todos los índices y Terraform
**destruiría y recrearía subredes que no cambiaron**.

### 4. Las AZ se descubren, no se escriben

Si `availability_zones` queda vacío, el módulo consulta las disponibles en la región con
`data.aws_availability_zones`. Eso elimina un hardcodeo y hace el módulo portable a
cualquier región sin editarlo.

### 5. Sin salida a internet, por construcción

La tabla de ruteo privada **no define ninguna ruta** hacia un Internet Gateway ni un NAT
Gateway. Las subredes no son alcanzables desde afuera porque no existe el camino, no porque
se haya olvidado configurarlo.

Además, un NAT Gateway cuesta unos **USD 32/mes** más el tráfico procesado: un gasto
injustificado cuando el único destino externo es S3.

### 6. Gateway Endpoint de S3

Sin él, el tráfico hacia S3 saldría a internet y exigiría un NAT Gateway. El endpoint de
tipo **Gateway** resuelve las dos cosas: el tráfico viaja por la red interna de AWS y **no
tiene costo**, a diferencia de los de tipo Interface, que se cobran por hora y por GB.

La asociación con la tabla de ruteo es lo que lo hace efectivo: sin ella el endpoint existe
pero ninguna subred lo usa.

### 7. Security group por defecto vaciado

AWS crea automáticamente un security group por defecto que **permite todo el tráfico entre
sus miembros**. Declararlo con `aws_default_security_group` sin reglas lo deja vacío, de modo
que ningún recurso lo herede abierto por accidente.

### 8. Dos roles, dos planos

| Rol | Plano | Puede |
|---|---|---|
| `role-data-processing-dev` | Data plane | `s3:ListBucket` (solo el prefijo), `s3:GetObject`, `s3:PutObject` bajo `raw/` |
| `role-plataforma-auditoria-dev` | Control plane | Leer configuración. **Deny explícito** sobre `s3:GetObject` y `kinesis:GetRecords` |

El de procesamiento separa los permisos en dos statements porque `ListBucket` es una acción
**sobre el bucket** mientras que `GetObject`/`PutObject` operan **sobre los objetos**:
requieren ARNs de distinto nivel.

El de auditoría puede ver **cómo está configurada** la plataforma pero no **qué datos**
contiene. Auditar no es leer.

### 9. Protección contra el *confused deputy*

La trust policy del rol de ejecución incluye una condición sobre `aws:SourceAccount`. Sin
ella, el servicio podría ser inducido a asumir el rol en nombre de un recurso de otra cuenta.

### 10. `default_tags` en el provider

En vez de repetir el bloque `tags` en cada recurso, el provider aplica `Environment`,
`ManagedBy` y `Proyecto` a todo lo que las soporte. `Environment` permite filtrar costos en
Cost Explorer; `ManagedBy` distingue lo gestionado por código de lo creado a mano por consola.

---

## Sobre el único `Resource: "*"` del proyecto

La política del rol de auditoría usa `"*"` en un statement. **Es inevitable y está acotado:**

Las acciones `Describe*` y `List*` del plano de control **no admiten permisos a nivel de
recurso** — la API de AWS no expone ARNs para ellas. Se mitiga con tres medidas:

1. Son operaciones de **solo lectura** sobre metadatos de configuración.
2. Hay una condición `aws:RequestedRegion` que las limita a una sola región.
3. Un statement `Deny` explícito bloquea toda lectura de datos.

Ningún permiso de **escritura** usa comodines en este proyecto.

---

## Validación

```bash
terraform fmt -check -recursive .
```

```bash
cd environments/dev && terraform validate
```

Estado actual: `fmt` sin diferencias · `validate` con `Success!` en los dos módulos, en el
bootstrap y en el entorno · `terraform plan` con **18 to add, 0 to change, 0 to destroy**
(ver [PLAN_OUTPUT.md](PLAN_OUTPUT.md)).

`tflint` no está instalado en el equipo de desarrollo, por lo que no se ejecutó.

---

## Higiene del repositorio

El [`.gitignore`](.gitignore) excluye `*.tfstate`, `.terraform/`, `*.tfvars`, `*.tfplan` y
credenciales. Los archivos `*.tfvars.example` **sí** se versionan: documentan qué variables
existen y con qué formato, y no terminan en `.tfvars`.

Para verificar que no se coló nada antes de subir:

```bash
git status --ignored --short
```

---

## Destrucción

Orden inverso al despliegue.

```bash
cd environments/dev && terraform destroy
```

```bash
cd ../../bootstrap && terraform destroy
```

⚠️ Destruir el bootstrap elimina el bucket donde vive el state de `dev`. Hacelo
**únicamente después** de haber destruido el entorno, o vas a quedar sin registro de los
recursos creados y habrá que borrarlos a mano desde la consola.

---

## Cómo se reutiliza para otro entorno

Duplicar `environments/dev/` como `environments/prod/` y ajustar tres cosas:

1. La `key` del backend en `backend.tf` (`prod/infraestructura-base.tfstate`).
2. Los valores del `terraform.tfvars`: `environment`, `vpc_cidr` y los CIDR de subred, en un
   espacio de red que no se solape (por ejemplo `10.2.0.0/16`).
3. `raw_bucket_force_destroy = false`, porque en producción esa bandera es la última barrera
   contra el borrado accidental de datos.

Los módulos **no se tocan**: toda la diferencia entre entornos vive en las variables.
