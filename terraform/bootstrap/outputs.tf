output "state_bucket" {
  description = "Bucket S3 del estado remoto"
  value       = aws_s3_bucket.tfstate.bucket
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR de PassFly"
  value       = aws_ecr_repository.passfly.repository_url
}

output "ci_role_arn" {
  description = "Rol de CI (sube imágenes a ECR)"
  value       = aws_iam_role.ci.arn
}

output "cd_role_arn" {
  description = "Rol de CD (terraform apply)"
  value       = aws_iam_role.cd.arn
}

output "plan_role_arn" {
  description = "Rol de solo lectura (terraform plan en pull requests)"
  value       = aws_iam_role.plan.arn
}

output "aws_region" {
  description = "Región"
  value       = var.aws_region
}
