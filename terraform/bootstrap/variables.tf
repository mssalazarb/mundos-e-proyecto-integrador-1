variable "aws_region" {
  description = "Región de AWS donde se crean los recursos."
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "Usuario u organización de GitHub dueño del repositorio."
  type        = string
}

variable "github_repo" {
  description = "Nombre del repositorio de GitHub."
  type        = string
  default     = "passfly"
}

variable "github_environment" {
  description = "Environment de GitHub que protege el despliegue (CD)."
  type        = string
  default     = "production"
}

variable "create_oidc_provider" {
  description = "Crear el proveedor OIDC de GitHub. Poner false si la cuenta ya tiene uno (solo puede existir uno por URL)."
  type        = bool
  default     = true
}
