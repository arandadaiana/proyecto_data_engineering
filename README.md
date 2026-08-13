# Proyecto Data Engineering — CoderHouse

Repositorio de entregas del curso. Cada carpeta es una entrega autocontenida:
tiene su propio código, su propia documentación y se despliega por separado.

| Entrega | Estado | Contenido |
|---|---|---|
| [`entrega_1/`](entrega_1/) | ✅ Completa | Infraestructura base en AWS con Terraform: VPC con subredes privadas, S3 como capa RAW de un Data Lake, rol IAM acotado y backend remoto con state locking. Tres ambientes (`dev`, `staging`, `prod`) sobre módulos compartidos. |
| [`entrega_2/`](entrega_2/) | ⏳ Pendiente | Aún sin definir. |

---

## Cómo navegar el repositorio

Cada entrega documenta su propio despliegue. Empezá por el README de la entrega
que te interese:

- **[entrega_1/README.md](entrega_1/README.md)** — requisitos, estructura, decisiones
  de diseño y pasos de despliegue de la infraestructura base.

## Convenciones comunes

El `.gitignore` vive en la raíz y aplica a todas las entregas. Excluye:

- **Estados de Terraform** (`*.tfstate`) — se guardan en S3, nunca en git.
- **Valores de variables** (`*.tfvars`) — pueden contener datos específicos del
  ambiente. Cada carpeta versiona en su lugar un `terraform.tfvars.example`
  que documenta qué variables existen y con qué formato.
- **Directorios de trabajo** (`.terraform/`) — contienen binarios de providers.

Los patrones no llevan barra inicial, así que funcionan a cualquier profundidad
del árbol sin importar en qué entrega estén.
