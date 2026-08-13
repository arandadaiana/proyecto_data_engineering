# Proyecto Data Engineering — Infraestructura como Código

Infraestructura base para una plataforma de datos en AWS, gestionada íntegramente con Terraform.

El proyecto despliega una VPC aislada con subredes privadas, un bucket S3 como capa RAW de un Data Lake, y un rol IAM de permisos acotados para los servicios de procesamiento.

**Región:** `us-east-1` · **Ambientes:** `dev` · `staging` · `prod`

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
│   ├── outputs.tf                # Nombres reales para configurar el backend
│   ├── terraform.tfvars.example  # Plantilla de valores (se versiona)
│   └── terraform.tfstate         # State LOCAL (ver decisión de diseño #1)
│
├── modules/                      # Módulos COMPARTIDOS por todos los ambientes
│   ├── network/                  # VPC, subredes, ruteo y VPC Endpoint
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── identity/                 # Rol IAM y política de permisos acotada
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── enviroments/                  # Un ambiente = una carpeta = un state propio
    ├── dev/
    │   ├── provider.tf           # Versión de Terraform, provider AWS y backend remoto
    │   ├── main.tf               # Orquestación: invoca módulos + crea el bucket RAW
    │   ├── variables.tf          # Declaración de variables (tipo + description + default)
    │   ├── outputs.tf            # Valores expuestos del ambiente completo
    │   ├── terraform.tfvars.example  # Plantilla documentada (se versiona)
    │   └── terraform.tfvars      # Valores reales (IGNORADO por git)
    │
    ├── staging/                  # Misma estructura, otras variables
    └── prod/                     # Misma estructura, otras variables
```

Las tres carpetas de `enviroments/` son idénticas en forma: cambian solo los valores
de las variables y la `key` del backend. Toda la lógica vive una sola vez en `modules/`.

---

## Recursos desplegados

### Capa `bootstrap` (backend de Terraform)

| Recurso | Nombre | Función |
|---|---|---|
| `aws_s3_bucket` | `coderhouse-terraform-2026-dev` | Almacena el archivo de estado remoto |
| `aws_s3_bucket_versioning` | — | Historial de versiones del state para recuperación |
| `aws_s3_bucket_server_side_encryption_configuration` | — | Cifrado AES256 en reposo |
| `aws_dynamodb_table` | `terraform-locks-dev` | State locking (control de concurrencia) |

### Capa de ambiente (infraestructura de datos)

Cada ambiente despliega el mismo juego de recursos; el sufijo `<env>` vale `dev`, `staging` o `prod`.

| Ambiente | VPC | Subredes privadas | Bucket RAW | `force_destroy` |
|---|---|---|---|---|
| `dev` | `10.0.0.0/16` | `10.0.1.0/24`, `10.0.2.0/24` | `datalake-raw-dev-<account_id>` | `true` |
| `staging` | `10.1.0.0/16` | `10.1.1.0/24`, `10.1.2.0/24` | `datalake-raw-staging-<account_id>` | `true` |
| `prod` | `10.2.0.0/16` | `10.2.1.0/24`, `10.2.2.0/24` | `datalake-raw-prod-<account_id>` | `false` |

Los rangos de red no se solapan entre ambientes: hoy no hace falta porque las VPC están
aisladas, pero evita un rediseño si en el futuro se conectan entre sí (peering).

**Raíz**

| Recurso | Nombre | Función |
|---|---|---|
| `aws_s3_bucket` | `datalake-raw-<env>-<account_id>` | Capa RAW del Data Lake |
| `data.aws_caller_identity` | — | Consulta el Account ID en tiempo de ejecución |

**Módulo `network`**

| Recurso | Configuración |
|---|---|
| VPC | Rango según `vpc_cidr`, DNS hostnames y resolución habilitados |
| Subredes privadas (×2) | Una por AZ, según `private_subnet_cidrs` y `availability_zones` |
| Route table privada | Sin ruta a internet (sin IGW ni NAT) |
| VPC Endpoint S3 | Tipo Gateway (`com.amazonaws.<aws_region>.s3`), asociado a la route table privada |

**Módulo `identity`**

| Recurso | Configuración |
|---|---|
| IAM Role | `role-data-processing-<env>` — asumible por Lambda y Kinesis Analytics |
| IAM Policy | `policy-s3-restricted-<env>` — `ListBucket` sobre el bucket, `GetObject`/`PutObject` solo bajo `raw-data/*` |
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

Cada ambiente es una carpeta con su propio state. Agregar uno implica duplicar la carpeta, ajustar variables y apuntar a otra `key` dentro del bucket — que es exactamente cómo se sumaron `staging` y `prod`.

Es una separación más fuerte que los *workspaces* de Terraform: los ambientes quedan realmente aislados, y un error en `dev` no puede alcanzar a `prod`.

Los módulos viven en `modules/`, en la raíz del repositorio, y no dentro de un ambiente. Si `modules/` colgara de `dev/`, `prod` tendría que apuntar a `../dev/modules/network`: producción pasaría a depender de una carpeta llamada "dev", y borrar o reorganizar `dev` rompería `prod`. En la raíz, los tres ambientes son pares que consumen la misma librería compartida.

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

### 11. `force_destroy` parametrizado por ambiente

Permite eliminar un bucket aunque contenga objetos, lo que hace posible un `terraform destroy` limpio.

Como es apropiado en práctica pero peligroso en producción, no está escrito a mano en el recurso sino que sale de la variable `raw_bucket_force_destroy`: vale `true` en `dev` y `staging`, y `false` en `prod`, donde es la última barrera contra el borrado accidental de datos.

Es el patrón general del proyecto: cuando un valor debe cambiar según el ambiente, se convierte en variable en lugar de duplicar código.

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

### 13. Un único bucket de state para los tres ambientes

`staging` y `prod` **no** tienen su propio bucket de backend: reutilizan el que creó el bootstrap, y se separan por la `key`:

```
coderhouse-terraform-2026-dev/
├── dev/infrastructure-base.tfstate
├── staging/infrastructure-base.tfstate
└── prod/infrastructure-base.tfstate
```

Los states siguen estando completamente aislados —son archivos distintos— y la tabla DynamoDB bloquea por `key`, así que un `apply` en `dev` no bloquea a `prod`.

Se eligió así por un motivo concreto: el bootstrap guarda su estado **en un archivo local único**. Volver a correrlo con `environment = "staging"` no crearía un backend nuevo, sino que Terraform interpretaría que el bucket de `dev` debe *renombrarse* a staging — es decir, destruiría el bucket donde vive el state de `dev`.

⚠️ **Deuda técnica asumida:** el nombre del bucket contiene `-dev`, lo cual es engañoso ahora que también guarda el state de producción. Corregirlo requiere crear el bucket definitivo, migrar los tres states con `terraform init -migrate-state` y recién ahí borrar el viejo. Se documenta en lugar de dejarlo implícito.

### 14. Región parametrizada en el VPC Endpoint

El `service_name` de un VPC Endpoint incluye la región: `com.amazonaws.us-east-1.s3`. Estaba escrito a mano, lo que hacía que el módulo `network` solo funcionara en `us-east-1` — y peor, fallaría de forma confusa si alguien cambiaba `aws_region` sin tocar el módulo.

Ahora se construye con la variable: `com.amazonaws.${var.aws_region}.s3`. El módulo recibe la región por su interfaz de variables, igual que el resto de sus parámetros, en lugar de asumirla.

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
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

`terraform init` descarga el provider de AWS, los módulos locales y configura el backend remoto. Debe reportar `Successfully configured the backend "s3"!`.

`terraform.tfvars` se carga solo si está en la **carpeta desde la que corrés el comando**. Un `.tfvars` en la raíz del repositorio nunca se lee.

### Paso 3 — Ambientes staging y prod

Idéntico a dev, cambiando de carpeta. No hay que volver a correr el bootstrap: los tres ambientes comparten el bucket de state (ver decisión #13).

```bash
cd enviroments/staging
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

⚠️ **Antes de aplicar en `prod`**, revisá el `plan` línea por línea. El flujo previsto es `dev` → `staging` → `prod`: un cambio se valida en los ambientes descartables antes de llegar a producción.

> **Nota de costos.** Cada ambiente crea su propia VPC, subredes, endpoint y bucket. La VPC, las subredes, el Gateway Endpoint y el rol IAM no tienen costo fijo; S3 cobra por lo almacenado. Aun así, si desplegás los tres solo para la entrega, conviene destruirlos después.

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

Orden inverso al despliegue: primero **todos** los ambientes, el bootstrap al final.

```bash
cd enviroments/prod
terraform destroy
```

```bash
cd enviroments/staging
terraform destroy
```

```bash
cd enviroments/dev
terraform destroy
```

```bash
cd bootstrap
terraform destroy
```

⚠️ Destruir el bootstrap elimina el bucket donde viven los states de los **tres** ambientes. Hacelo **únicamente después** de haber destruido todos, o vas a quedar sin registro de los recursos creados y habrá que borrarlos a mano desde la consola.

⚠️ `prod` tiene `raw_bucket_force_destroy = false`. Si su bucket RAW tiene objetos, el `destroy` va a fallar a propósito: hay que vaciarlo primero. Es la protección funcionando, no un error.

---

## Notas y mejoras pendientes

**Advertencia de parámetro obsoleto.** Terraform emite un warning sobre `dynamodb_table` en el bloque `backend`, en favor de `use_lockfile = true` (bloqueo nativo de S3, disponible desde Terraform 1.10). El parámetro actual sigue siendo funcional. Migrar volvería innecesaria la tabla DynamoDB del bootstrap.

**Nombre del bucket de state.** Contiene `-dev` pero aloja también los states de `staging` y `prod` (ver decisión #13). Requiere una migración con `terraform init -migrate-state`.

**Nombres de carpeta con erratas.** `poyecto_data_engineering` y `enviroments` tienen errores de tipeo. Renombrarlas no afecta a la infraestructura desplegada —solo hay que volver a correr `terraform init`— pero conviene hacerlo cuanto antes.

**Duplicación entre ambientes.** Los tres `variables.tf` y `main.tf` de `enviroments/` son casi idénticos. Es la contrapartida aceptada de la separación por carpetas: se gana aislamiento real y se paga con repetición. Herramientas como Terragrunt existen justamente para eliminarla, a costa de sumar una dependencia externa.

**Formato del código.** Los `.tf` no están pasados por `terraform fmt` (no tienen indentación). No afecta el funcionamiento; se normaliza con `terraform fmt -recursive` desde la raíz.
