# Proyecto Data Engineering — CoderHouse

Repositorio de entregas del curso. Cada carpeta es una entrega autocontenida:
tiene su propio código, su propia documentación y se despliega por separado.

| Entrega | Estado | Contenido |
|---|---|---|
| [`entrega_1/`](entrega_1/) | ✅ Completa | Infraestructura base en AWS con Terraform: VPC con subredes privadas, S3 como capa RAW de un Data Lake, rol IAM acotado y backend remoto con state locking. Tres ambientes (`dev`, `staging`, `prod`) sobre módulos compartidos. |
| [`entrega_2/`](entrega_2/) | ✅ Completa | Diseño del backend remoto y la gobernanza del estado: arquitectura multi-cuenta con S3 como state remoto, DynamoDB como capa de locking, cifrado con KMS y versionado. Incluye diagramas y la justificación de por qué reduce el riesgo de corrupción frente a un estado local. |

---

## Cómo navegar el repositorio

Cada entrega documenta su propio despliegue. Empezá por el README de la entrega
que te interese:

- **[entrega_1/README.md](entrega_1/README.md)** — requisitos, estructura, decisiones
  de diseño y pasos de despliegue de la infraestructura base.
- **[entrega_2/README.md](entrega_2/README.md)** — diagramas del backend remoto, flujo de
  locking y justificación de la estrategia de aislamiento entre entornos.

Las dos entregas hablan del mismo problema desde ángulos distintos: la primera **construye**
la infraestructura con Terraform; la segunda diseña cómo **proteger el estado** que esa
infraestructura genera cuando trabaja un equipo entero sobre él.

## Convenciones comunes

El `.gitignore` vive en la raíz y aplica a todas las entregas. Excluye:

- **Estados de Terraform** (`*.tfstate`) — se guardan en S3, nunca en git.
- **Valores de variables** (`*.tfvars`) — pueden contener datos específicos del
  ambiente. Cada carpeta versiona en su lugar un `terraform.tfvars.example`
  que documenta qué variables existen y con qué formato.
- **Directorios de trabajo** (`.terraform/`) — contienen binarios de providers.

Los patrones no llevan barra inicial, así que funcionan a cualquier profundidad
del árbol sin importar en qué entrega estén.
