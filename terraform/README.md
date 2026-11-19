# Infraestructura de PassFly en AWS

```
GitHub Actions ──OIDC──▶ AWS
  CI PassFly:  lint · test · Snyk · build ──▶ ECR (imagen :<sha>)
  CD Deploy / Terraform: terraform apply (estado en S3) ──▶ VPC + EC2 (Docker Compose)
                                                              ├─ passfly     :80
                                                              ├─ prometheus  (solo localhost)
                                                              └─ grafana     :3001 (solo admin_cidr)
```

| Directorio | Contenido | Quién lo ejecuta |
|---|---|---|
| `bootstrap/` | Bucket S3 de estado, repositorio ECR, proveedor OIDC y roles IAM (`passfly-github-ci`, `-plan`, `-cd`) | Workflow **Bootstrap**, una vez |
| `main/` | VPC, subred pública, security group, rol de instancia, EC2 Ubuntu 24.04, IP elástica | Los pipelines |
| `monitoring/` | `prometheus.yml` y dashboard/provisioning de Grafana (los lee `main/` y el compose local) | — |

Seguridad: sin claves de AWS en GitHub (OIDC) y **tres roles con mínimo privilegio**: CI solo sube a ECR, PLAN solo lee (pull requests) y CD despliega únicamente desde el environment `production`. Además: sin SSH (acceso por SSM), IMDSv2 obligatorio, disco cifrado, imágenes ECR inmutables con escaneo, Prometheus no expuesto y Grafana restringido por CIDR.

## Puesta en marcha (todo desde GitHub)

Nada se ejecuta en tu máquina: el bucket de estado, ECR, OIDC y los roles los crea el workflow **Bootstrap**.

### 1. Crear el repositorio y subir el código

```bash
gh auth login
gh repo create passfly --private --source . --push   # desde la raíz del monorepo
```

El primer push ejecuta CI: lint, test y seguridad pasan, pero el job `build` fallará al publicar en ECR porque aún no existe el rol. Es esperado; Bootstrap lo relanza más tarde.

### 2. Cargar credenciales y variables en GitHub

El **único** punto de arranque con claves estáticas: GitHub necesita alguna credencial para crear el primer rol OIDC. Crea una clave de acceso **nueva** para tu usuario IAM (o uno dedicado) y úsala solo para Bootstrap.

| Tipo | Nombre | Valor |
|---|---|---|
| Secreto (repo o environment `bootstrap`) | `AWS_ACCESS_KEY_ID` | clave de acceso |
| Secreto (repo o environment `bootstrap`) | `AWS_SECRET_ACCESS_KEY` | clave secreta |
| Variable | `AWS_ACCOUNT_ID` | ID de tu cuenta de 12 dígitos |
| Variable | `AWS_REGION` | p. ej. `us-east-1` |
| Variable *(recomendada)* | `ADMIN_CIDR` | tu IP, p. ej. `203.0.113.7/32` |
| Secreto *(opcional)* | `SNYK_TOKEN` | token gratuito de snyk.io |

```bash
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh variable set AWS_ACCOUNT_ID --body 123456789012
gh variable set AWS_REGION --body us-east-1
```

Los nombres de los roles y del bucket son fijos (`passfly-github-*`, `passfly-tfstate-<cuenta>-<región>`), así que no hay que copiar ninguna salida de Terraform a GitHub.

### 3. Ejecutar Bootstrap

Actions → **Bootstrap** → *Run workflow*. Crea el bucket (con estado local temporal que migra a S3 en el mismo job), ECR, proveedor OIDC y los roles. Al terminar **lanza CI PassFly**, que publica la primera imagen, y CD Deploy despliega la infraestructura.

> Si CD Deploy no arranca solo tras ese CI, lánzalo a mano: Actions → **CD Deploy** → *Run workflow* (sin tag: usa la imagen más reciente de ECR).

Después puedes **borrar los secretos `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`** y la clave en IAM: de aquí en adelante todo usa OIDC.

### 4. Día a día

| Cambias… | Pasa… |
|---|---|
| `passfly/` | CI → ECR → CD Deploy (nueva imagen + `apply`) |
| `terraform/` | Terraform: plan en el PR, `apply` al integrar en `main`, misma imagen |
| Ambos en un commit | Corren los dos y se serializan; el resultado final usa la imagen nueva |

La URL de la app y de Grafana aparecen en el resumen del job de despliegue. La contraseña de Grafana (usuario `admin`) está en el estado remoto: `terraform output -raw grafana_admin_password` desde `terraform/main` tras un `terraform init` con el backend S3.

### 5. Destruir (evita costos)

Actions → **CD Deploy** → *Run workflow* → acción `destroy`. Después, si quieres borrar todo, vacía el bucket de estado y borra con `terraform destroy` los recursos de `bootstrap/` (requiere credenciales de administrador).

## Notas

- `bootstrap/` solo se ejecuta con el workflow manual **Bootstrap** (usa claves estáticas porque crea los propios roles OIDC). Los cambios en ese directorio únicamente se validan en CI.
- Cada imagen nueva (o cambio en `monitoring/` o en el cloud-init) **reemplaza la instancia** (`user_data_replace_on_change`); la IP elástica se conserva. Hay unos minutos de indisponibilidad.
- Costo aproximado: una `t3.micro`, 20 GB de disco y una IP elástica. Destruye el stack al terminar la demo.
- `ec2:*` en el rol CD es amplio a propósito para simplificar; en producción conviene acotarlo.
