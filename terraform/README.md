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
| `bootstrap/` | Bucket S3 de estado, repositorio ECR, proveedor OIDC y roles IAM (`passfly-github-ci`, `-plan`, `-cd`) | Tú, **una vez**, a mano |
| `main/` | VPC, subred pública, security group, rol de instancia, EC2 Ubuntu 24.04, IP elástica | Los pipelines |
| `monitoring/` | `prometheus.yml` y dashboard/provisioning de Grafana (los lee `main/` y el compose local) | — |

Seguridad: sin claves de AWS en GitHub (OIDC) y **tres roles con mínimo privilegio**: CI solo sube a ECR, PLAN solo lee (pull requests) y CD despliega únicamente desde el environment `production`. Además: sin SSH (acceso por SSM), IMDSv2 obligatorio, disco cifrado, imágenes ECR inmutables con escaneo, Prometheus no expuesto y Grafana restringido por CIDR.

## Puesta en marcha

### 1. Bootstrap (una sola vez)

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="github_owner=TU_USUARIO_GITHUB" -var="github_repo=NOMBRE_DEL_REPO"
# Si tu cuenta ya tiene el proveedor OIDC de GitHub: -var="create_oidc_provider=false"
terraform output
```

### 2. Configurar GitHub

**Settings → Secrets and variables → Actions → Variables**

| Variable | Valor (salida del bootstrap) |
|---|---|
| `AWS_REGION` | `aws_region` |
| `AWS_ROLE_ARN_CI` | `ci_role_arn` |
| `AWS_ROLE_ARN_PLAN` | `plan_role_arn` |
| `AWS_ROLE_ARN_CD` | `cd_role_arn` |
| `TF_STATE_BUCKET` | `state_bucket` |
| `ADMIN_CIDR` *(recomendada)* | tu IP, p. ej. `203.0.113.7/32` |

Secreto opcional: `SNYK_TOKEN` (token gratuito de snyk.io).
Crea el environment **production** (Settings → Environments), idealmente con un revisor requerido.

### 3. Primer despliegue

Haz push a `main` con un cambio en `passfly/`: CI publica la imagen y CD despliega todo.
(Alternativa: Actions → **CD Deploy** → *Run workflow* con un `image_tag` ya existente en ECR.)

> Hasta que exista un primer despliegue, el workflow **Terraform** no sabe qué imagen usar y lo indica con un error claro. Después de eso reutiliza el tag guardado en el estado.

### 4. Día a día

| Cambias… | Pasa… |
|---|---|
| `passfly/` | CI → ECR → CD Deploy (nueva imagen + `apply`) |
| `terraform/` | Terraform: plan en el PR, `apply` al integrar en `main`, misma imagen |
| Ambos en un commit | Corren los dos y se serializan; el resultado final usa la imagen nueva |

Contraseña de Grafana (usuario `admin`):

```bash
cd terraform/main
terraform init -backend-config="bucket=<state_bucket>" -backend-config="key=passfly/terraform.tfstate" -backend-config="region=<region>"
terraform output -raw grafana_admin_password
```

### 5. Destruir (evita costos)

Actions → **CD Deploy** → *Run workflow* → acción `destroy`. Después, si quieres borrar todo, `terraform destroy` en `bootstrap/` (vacía antes el bucket de estado).

## Notas

- `bootstrap/` **no** lo ejecuta ningún pipeline: crea los propios roles que usan los pipelines. Los cambios ahí solo se validan en CI.
- Cada imagen nueva (o cambio en `monitoring/` o en el cloud-init) **reemplaza la instancia** (`user_data_replace_on_change`); la IP elástica se conserva. Hay unos minutos de indisponibilidad.
- Costo aproximado: una `t3.micro`, 20 GB de disco y una IP elástica. Destruye el stack al terminar la demo.
- `ec2:*` en el rol CD es amplio a propósito para simplificar; en producción conviene acotarlo.
