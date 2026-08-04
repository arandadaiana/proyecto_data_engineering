# Proyecto Data Engineering — Infraestructura como Código

Infraestructura base para una plataforma de datos en AWS, gestionada íntegramente con Terraform.

El proyecto despliega una VPC aislada con subredes privadas, un bucket S3 como capa RAW de un Data Lake, y un rol IAM de permisos acotados para los servicios de procesamiento.

**Región:** `us-east-1` · **Ambiente actual:** `dev`

---

## Requisitos previos

| Herramienta | Versión | Verificar con |
|---|---|---|
| Terraform | >= 1.5.0 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| Credenciales AWS | Usuario IAM configurado | `aws sts get-caller-identity` |

Las credenciales se cargan con `aws configure` y quedan en `~/.aws/credentials`. **Nunca se declaran dentro de los archivos `.tf`** — Terraform las toma automáticamente del perfil del sistema.

---

## Estructura del proyecto

```
poyecto_data_engineering/
│
├── bootstrap/                    # Infraestructura del propio Terraform (se corre UNA vez)
│   ├── main.tf                   # Bucket S3 del state + tabla DynamoDB de locks
│   ├── variables.tf              # aws_region, environment
│   ├── outputs.tf                # Nombres reales para configurar el backend de dev
│   └── terraform.tfstate         # State LOCAL (ver decisión de diseño #1)
│
└── enviroments/
    └── dev/
        ├── provider.tf           # Versión de Terraform, provider AWS y backend remoto
        ├── main.tf               # Orquestación: invoca módulos + crea el bucket RAW
        ├── variables.tf          # aws_region, environment, vpc_cidr
        ├── outputs.tf            # Valores expuestos del ambiente completo
        │
        └── modules/
            ├── network/          # VPC, subredes, ruteo y VPC Endpoint
            │   ├── main.tf
            │   ├── variables.tf
            │   └── outputs.tf
            │
            └── identity/         # Rol IAM y política de permisos acotada
                ├── main.tf
                ├── variables.tf
                └── outputs.tf
```

---

## Recursos desplegados

### Capa `bootstrap` (backend de Terraform)

| Recurso | Nombre | Función |
|---|---|---|
| `aws_s3_bucket` | `coderhouse-terraform-2026-dev` | Almacena el archivo de estado remoto |
| `aws_s3_bucket_versioning` | — | Historial de versiones del state para recuperación |
| `aws_s3_bucket_server_side_encryption_configuration` | — | Cifrado AES256 en reposo |
| `aws_dynamodb_table` | `terraform-locks-dev` | State locking (control de concurrencia) |

### Capa `dev` (infraestructura de datos)

**Raíz**

| Recurso | Nombre | Función |
|---|---|---|
| `aws_s3_bucket` | `datalake-raw-dev-<account_id>` | Capa RAW del Data Lake |
| `data.aws_caller_identity` | — | Consulta el Account ID en tiempo de ejecución |

**Módulo `network`**

| Recurso | Configuración |
|---|---|
| VPC | `10.0.0.0/16`, DNS hostnames y resolución habilitados |
| Subredes privadas (×2) | `10.0.1.0/24` en `us-east-1a`, `10.0.2.0/24` en `us-east-1b` |
| Route table privada | Sin ruta a internet (sin IGW ni NAT) |
| VPC Endpoint S3 | Tipo Gateway, asociado a la route table privada |

**Módulo `identity`**

| Recurso | Configuración |
|---|---|
| IAM Role | `role-data-processing-dev` — asumible por Lambda y Kinesis Analytics |
| IAM Policy | `policy-s3-restricted-dev` — `ListBucket` sobre el bucket, `GetObject`/`PutObject` solo bajo `raw-data/*` |
| Policy attachment | Vincula la política al rol |

---

## Decisiones de diseño

### 1. Bootstrap separado con state local

El backend remoto necesita un bucket S3 y una tabla DynamoDB **que todavía no existen** la primera vez que se despliega. No se puede guardar el estado en un bucket que aún no fue creado.

Para resolver ese problema de arranque, la carpeta `bootstrap/` se despliega con **state local** (`terraform.tfstate` en disco) y su única responsabilidad es crear la infraestructura que después usará el resto del proyecto.

Se corre **una sola vez** y prácticamente no se vuelve a tocar.

### 2. Backend remoto S3 + DynamoDB

El estado del ambiente `dev` no vive en la máquina de nadie, sino en S3. Esto aporta cuatro cosas:

- **Trabajo compartido** — cualquier integrante del equipo opera sobre el mismo estado.
- **Durabilidad** — el estado no se pierde si falla un disco local.
- **Versionado** — el bucket tiene versioning activo; un state corrupto se puede revertir.
- **Cifrado** — AES256 en reposo, relevante porque el state guarda atributos sensibles en texto plano.

La tabla DynamoDB implementa **state locking**: si dos personas corren `apply` en simultáneo, la segunda queda bloqueada hasta que termine la primera. Sin eso, dos escrituras concurrentes corrompen el estado.

### 3. El nombre del bucket va hardcodeado en el backend

En `provider.tf` el bloque `backend "s3"` tiene los nombres escritos como texto literal, no como variables:

```hcl
backend "s3" {
  bucket = "coderhouse-terraform-2026-dev"
  ...
}
```

No es un descuido: **Terraform no admite variables ni interpolación dentro del bloque `backend`**. Necesita saber dónde está el state antes de evaluar cualquier expresión del código.

⚠️ Como consecuencia, este nombre puede desincronizarse del bootstrap (donde sí se construye con `${var.environment}`). Los outputs del bootstrap existen justamente para copiar los valores correctos sin equivocarse:

```bash
cd bootstrap
terraform output
```

### 4. Módulos por dominio funcional

La infraestructura se divide en `network` e `identity` en lugar de un único archivo monolítico, por tres motivos:

- **Reutilización** — el mismo módulo sirve para `dev`, `staging` y `prod` cambiando solo las variables.
- **Aislamiento** — un cambio en la política de IAM no obliga a leer el código de red.
- **Contratos explícitos** — cada módulo declara qué recibe (`variables.tf`) y qué expone (`outputs.tf`).

Los módulos nunca acceden a valores del exterior por su cuenta: todo entra por variables y sale por outputs.

### 5. Estructura `enviroments/<ambiente>/`

Cada ambiente es una carpeta con su propio state y su propio backend. Agregar `prod` implica duplicar la carpeta, ajustar variables y apuntar a otra `key` dentro del bucket.

Es una separación más fuerte que los *workspaces* de Terraform: los ambientes quedan realmente aislados, y un error en `dev` no puede alcanzar a `prod`.

### 6. Account ID resuelto en tiempo de ejecución

El sufijo del bucket RAW no está escrito a mano, sino que se consulta:

```hcl
data "aws_caller_identity" "current" {}
```

Los nombres de bucket en S3 son **únicos a nivel mundial**, así que necesitan un sufijo que evite colisiones. Usar el Account ID real —en vez de un número fijo— hace que el código funcione sin modificaciones en cualquier cuenta de AWS.

Un `data source` solo consulta información existente; no crea recursos ni genera costos.

### 7. Permisos IAM de mínimo privilegio

La política evita deliberadamente los comodines amplios del tipo `s3:*` sobre `*`:

```hcl
# Listar: solo este bucket
Resource = [var.bucket_arn]

# Leer/escribir objetos: solo bajo el prefijo raw-data/
Resource = ["${var.bucket_arn}/${var.prefix}"]
```

La separación en dos *statements* es necesaria por cómo funciona S3: `ListBucket` es una acción **sobre el bucket**, mientras que `GetObject` y `PutObject` operan **sobre los objetos**. Requieren ARNs de distinto nivel.

El rol tampoco es genérico: su *trust policy* lo restringe a Lambda y Kinesis Analytics, los servicios que efectivamente lo necesitan.

### 8. Subredes privadas sin salida a internet

Las subredes no tienen Internet Gateway ni NAT Gateway. Es una decisión de seguridad y de costo:

- Los datos de la capa RAW no deben ser alcanzables desde internet.
- Un NAT Gateway cuesta aproximadamente **USD 32/mes** más el tráfico procesado — un gasto injustificado en un ambiente de desarrollo.

### 9. VPC Endpoint tipo Gateway para S3

Sin él, el tráfico hacia S3 saldría a internet y requeriría un NAT Gateway. El endpoint Gateway resuelve las dos cosas a la vez:

- El tráfico viaja por la red interna de AWS, nunca sale a internet pública.
- **No tiene costo** (a diferencia de los endpoints tipo Interface, que se cobran por hora y por GB).

### 10. Dos AZs para alta disponibilidad

Las subredes se distribuyen en `us-east-1a` y `us-east-1b`. Una zona de disponibilidad es un datacenter físicamente independiente; si una falla, la otra sigue operativa.

Además, varios servicios de AWS (RDS, ALB, EKS) **exigen** subredes en al menos dos AZs, así que la base queda preparada para incorporarlos.

### 11. `force_destroy = true` en los buckets

Permite eliminar un bucket aunque contenga objetos, lo que hace posible un `terraform destroy` limpio.

⚠️ **Es apropiado solo en ambientes de práctica.** En producción esta bandera debe estar en `false`: es la última barrera contra el borrado accidental de datos.

### 12. Etiquetado consistente

Todos los recursos llevan las mismas etiquetas base:

```hcl
tags = {
  Name        = "..."
  Environment = var.environment
  ManagedBy   = "Terraform"
}
```

`Environment` permite filtrar costos por ambiente en AWS Cost Explorer. `ManagedBy` distingue lo gestionado por código de lo creado manualmente por consola — información clave para saber qué se puede modificar a mano y qué no.

---

## Despliegue

El orden importa: `bootstrap` primero, siempre.

### Paso 1 — Backend (una única vez)

```bash
cd bootstrap
terraform init
terraform apply
```

Al terminar, anotá los valores que devuelve:

```bash
terraform output
```

Deben coincidir con lo declarado en `enviroments/dev/provider.tf`.

### Paso 2 — Ambiente dev

```bash
cd enviroments/dev
terraform init
terraform plan
terraform apply
```

`terraform init` descarga el provider de AWS, los módulos locales y configura el backend remoto. Debe reportar `Successfully configured the backend "s3"!`.

### Consultar los outputs

```bash
terraform output
```

| Output | Contenido |
|---|---|
| `vpc_id` | ID de la VPC |
| `private_subnets` | Lista de IDs de las subredes privadas |
| `s3_endpoint_id` | ID del VPC Endpoint de S3 |
| `data_role_arn` | ARN del rol IAM de procesamiento |
| `raw_bucket_name` | Nombre del bucket de la capa RAW |

---

## Destrucción

Orden inverso al despliegue:

```bash
cd enviroments/dev
terraform destroy
```

```bash
cd bootstrap
terraform destroy
```

⚠️ Destruir el bootstrap elimina el bucket donde vive el state de `dev`. Hacelo **únicamente después** de haber destruido `dev`, o vas a quedar sin registro de los recursos creados y habrá que borrarlos a mano desde la consola.

---

## Notas y mejoras pendientes

**Advertencia de parámetro obsoleto.** Terraform emite un warning sobre `dynamodb_table` en el bloque `backend`, en favor de `use_lockfile = true` (bloqueo nativo de S3, disponible desde Terraform 1.10). El parámetro actual sigue siendo funcional. Migrar volvería innecesaria la tabla DynamoDB del bootstrap.

**Región fija en el módulo `network`.** El `service_name` del VPC Endpoint está escrito como `com.amazonaws.us-east-1.s3`. Para que el módulo sea portable a otras regiones habría que parametrizarlo.

**Variables del módulo `network` sin propagar.** `private_subnet_cidrs` y `availability_zones` no se pasan desde `enviroments/dev/main.tf`; el módulo usa sus valores por defecto. Funciona, pero conviene declararlas explícitamente en la invocación para que la configuración del ambiente quede visible en un solo lugar.

**Nombres de carpeta con erratas.** `poyecto_data_engineering` y `enviroments` tienen errores de tipeo. Renombrarlas no afecta a la infraestructura desplegada —solo hay que volver a correr `terraform init`— pero conviene hacerlo antes de sumar más ambientes.
