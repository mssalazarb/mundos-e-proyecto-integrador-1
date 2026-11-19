# PassFly (monorepo)

Generador de contraseñas seguras desplegado en AWS con CI/CD en GitHub Actions.

```
.
├── passfly/      # Aplicación (Node.js + Express + frontend). Ver passfly/README.md
├── terraform/    # Infraestructura AWS. Ver terraform/README.md
│   ├── bootstrap/   # Estado S3, ECR y roles OIDC (se ejecuta una vez, a mano)
│   ├── main/        # VPC + EC2 + Docker Compose (lo despliega el pipeline)
│   └── monitoring/  # Prometheus y dashboard de Grafana
├── docker-compose.yml   # Stack local: app + Prometheus + Grafana
└── .github/workflows/
```

## Pipelines

| Workflow | Se activa con | Qué hace |
|---|---|---|
| **Bootstrap** (`bootstrap.yml`) | Manual, una vez | Crea desde GitHub el bucket de estado, ECR, OIDC y roles IAM; luego lanza CI |
| **CI PassFly** (`ci-passfly.yml`) | PR o push que toque `passfly/**` (o manual) | lint → test → `npm audit` + Snyk → build Docker + SBOM → **push a ECR solo en `main`** y si todo pasó |
| **CD Deploy** (`cd-deploy.yml`) | CI exitoso en `main`, o manual | `terraform apply` con la imagen recién publicada: despliega todo |
| **Terraform** (`terraform.yml`) | PR o push que toque `terraform/**` | PR: fmt + validate + **plan** (solo lectura). Push a `main`: **apply** reutilizando la imagen ya desplegada |

`_terraform-apply.yml` es el workflow reutilizable que comparten CD Deploy y Terraform. Los despliegues se serializan (un solo `apply` a la vez sobre el estado).

```
cambio en passfly/    ──▶ CI PassFly ──▶ ECR ──▶ CD Deploy ──▶ terraform apply (tag nuevo)
cambio en terraform/  ──▶ Terraform  ──▶ PR: plan │ main: terraform apply (tag actual)
```

## Local

```bash
docker compose up --build   # app :3000 · Prometheus :9090 · Grafana :3001 (admin/admin)
```

Puesta en marcha en AWS: [`terraform/README.md`](terraform/README.md).
