variable "aws_region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-1"
}

variable "image_tag" {
  description = "Tag de la imagen de PassFly en ECR (el pipeline usa el SHA del commit)."
  type        = string
}

variable "ecr_repository_name" {
  description = "Nombre del repositorio ECR creado en el bootstrap."
  type        = string
  default     = "passfly"
}

variable "instance_type" {
  description = "Tipo de instancia EC2."
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subred pública."
  type        = string
  default     = "10.20.1.0/24"
}

variable "admin_cidr" {
  description = "CIDR autorizado a entrar a Grafana (puerto 3001). Restringe a tu IP, p. ej. 203.0.113.7/32."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr debe ser un CIDR válido."
  }
}
