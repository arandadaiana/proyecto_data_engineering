# Entrega 3 — Módulo reutilizable con `for_each`

Módulo de Terraform que crea la capa RAW de un Data Lake **con un bucket S3 por
entorno**, a partir de una sola variable. El versionado se activa o no según el
entorno, y los ARNs se exponen como mapa para que otros módulos los consuman.

---

## Estructura

```
entrega_3/
├── modules/
│   └── data_lake/            # El módulo propiamente dicho
│       ├── main.tf           # data source + buckets + versionado
│       ├── variables.tf      # project_prefix, environments
│       └── outputs.tf        # bucket_arns, bucket_ids
│
└── ejemplo/                  # Cómo se invoca el módulo
    ├── provider.tf
    ├── main.tf               # llama al módulo + política IAM de ejemplo
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars.example
```

El módulo no se ejecuta solo: se invoca desde una raíz. La carpeta `ejemplo/`
cumple ese papel y sirve para validar el módulo sin desplegar nada.

---

## Uso

```hcl
module "data_lake" {
  source = "../modules/data_lake"

  project_prefix = "datalake-ventas"

  environments = {
    dev     = { versioning_enabled = false }
    staging = { versioning_enabled = false }
    prod    = { versioning_enabled = true }
  }
}
```

Eso crea tres buckets y devuelve:

```hcl
bucket_arns = {
  dev     = "arn:aws:s3:::datalake-ventas-dev-111122223333"
  staging = "arn:aws:s3:::datalake-ventas-staging-111122223333"
  prod    = "arn:aws:s3:::datalake-ventas-prod-111122223333"
}
```

Para agregar un cuarto entorno alcanza con sumar una entrada al mapa. **No hay
que tocar el módulo.**

---

## Cómo funciona, paso a paso

### 1. La variable `environments`

```hcl
variable "environments" {
  type = map(object({
    versioning_enabled = bool
  }))
}
```

El tipo se lee de adentro hacia afuera:

| Capa | Qué significa |
|---|---|
| `bool` | Solo `true` o `false` |
| `object({ versioning_enabled = bool })` | Un paquete con un campo etiquetado |
| `map(...)` | Una colección de esos paquetes, cada uno con nombre |

En la práctica es una tabla: la clave es el nombre del entorno, el valor es su
configuración.

### 2. `for_each` sobre el mapa

```hcl
resource "aws_s3_bucket" "data_lake" {
  for_each = var.environments
  bucket   = "${var.project_prefix}-${each.key}-${data.aws_caller_identity.current.account_id}"
}
```

`for_each` repite el bloque una vez por entrada del mapa. En cada vuelta:

- **`each.key`** → el nombre del entorno (`"dev"`)
- **`each.value`** → su objeto (`{ versioning_enabled = false }`)

El nombre del bucket se arma por interpolación (`${...}` inserta un valor dentro
del texto). El **Account ID** va al final porque los nombres de bucket en S3 son
únicos a nivel mundial: sin un sufijo propio, `datalake-ventas-dev` colisionaría
con cualquier otra cuenta que lo haya tomado antes.

### 3. Versionado condicional

```hcl
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = var.environments
  bucket   = aws_s3_bucket.data_lake[each.key].id

  versioning_configuration {
    status = each.value.versioning_enabled ? "Enabled" : "Suspended"
  }
}
```

`aws_s3_bucket.data_lake[each.key]` selecciona, del grupo de buckets creado
antes, el que corresponde a este mismo entorno. Los corchetes eligen **por
nombre**, no por posición.

El operador ternario (`condición ? si_true : si_false`) traduce el booleano de la
variable al estado que espera la API de S3.

### 4. Outputs como mapa

```hcl
output "bucket_arns" {
  value = { for env, bucket in aws_s3_bucket.data_lake : env => bucket.arn }
}
```

Esta expresión recorre los buckets creados y arma un mapa nuevo: `env` pasa a ser
la clave y el ARN el valor. La flecha `=>` significa "apunta a".

Devolver un **mapa** y no una lista es lo que habilita la composición:

```hcl
Resource = ["${module.data_lake.bucket_arns["prod"]}/*"]
```

El consumidor pide el ARN **por nombre de entorno**, sin depender del orden de
creación ni de cuántos entornos existan.

---

## Decisiones de diseño

### Por qué `map` con `for_each` y no `list` con `count`

Es la decisión central del módulo.

Con `for_each` sobre un mapa, Terraform direcciona cada recurso por su clave:

```
aws_s3_bucket.data_lake["dev"]
aws_s3_bucket.data_lake["prod"]
```

Con `count` sobre una lista, los direcciona por posición:

```
aws_s3_bucket.data_lake[0]
aws_s3_bucket.data_lake[1]
```

La diferencia aparece al **agregar un entorno en el medio**. Si la lista era
`[dev, prod]` y se inserta `staging`, entonces `staging` ocupa la posición 1 —que
antes era `prod`— y `prod` se corre a la 2. Terraform interpreta que el recurso 1
cambió de nombre y que apareció uno nuevo: **destruye y recrea el bucket de
producción**, con los datos adentro, sin que nadie haya tocado esa línea.

Con un mapa eso no puede pasar: `dev` es `["dev"]` para siempre.

> **Regla práctica:** si los elementos tienen identidad propia (un nombre, un
> entorno, un cliente), va `for_each` sobre un mapa. `count` queda para elementos
> genuinamente intercambiables.

### Por qué `"Suspended"` y no `"Disabled"`

AWS solo acepta `Disabled` en buckets que **nunca** tuvieron versionado. Apenas se
activa una vez, el único camino de vuelta es `Suspended`; usar `Disabled` en ese
caso hace fallar el `apply`. `Suspended` funciona en ambos escenarios, así que es
el valor correcto para un módulo reutilizable que no sabe en qué estado está el
bucket que va a gestionar.

### Por qué el Account ID en el nombre

Los nombres de bucket compiten contra todas las cuentas de AWS del mundo. Consultar
el Account ID con `data "aws_caller_identity"` resuelve dos problemas a la vez:
garantiza unicidad y permite aplicar el módulo en cualquier cuenta sin editar
código. Un `data source` solo lee: no crea recursos ni genera costo.

### Validaciones en las variables

`project_prefix` valida contra la regla de nombres de S3 (solo minúsculas, números
y guiones). Sin eso, un prefijo con mayúsculas o guiones bajos falla recién durante
el `apply`, con un error de la API poco descriptivo. Con la validación, falla en el
`plan` y con un mensaje claro.

---

## Verificación

```bash
cd ejemplo
terraform init -backend=false
terraform validate
```

Estado actual: `Success! The configuration is valid.` · `terraform fmt` sin
diferencias.

> `terraform plan` y `apply` requieren credenciales de AWS y **crean recursos
> reales**. Los buckets S3 no tienen costo fijo, pero se cobra lo almacenado.

---

## Posible extensión

Con `optional()` los entornos pueden heredar valores por defecto seguros, de modo
que `dev = {}` sea una declaración válida:

```hcl
variable "environments" {
  type = map(object({
    versioning_enabled = optional(bool, true)
    force_destroy      = optional(bool, false)
  }))
}
```

Requiere Terraform >= 1.3; este proyecto exige >= 1.5, así que está disponible.
