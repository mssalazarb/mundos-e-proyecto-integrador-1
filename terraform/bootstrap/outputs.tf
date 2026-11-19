output "state_bucket" {
  description = "Bucket S3 del estado remoto -> variable de GitHub TF_STATE_BUCKET"
  value       = aws_s3_bucket.tfstate.bucket
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR de PassFly"
  value       = aws_ecr_repository.passfly.repository_url
}

output "ci_role_arn" {
  description = "-> variable de GitHub AWS_ROLE_ARN_CI"
  value       = aws_iam_role.ci.arn
}

output "cd_role_arn" {
  description = "-> variable de GitHub AWS_ROLE_ARN_CD"
  value       = aws_iam_role.cd.arn
}

output "plan_role_arn" {
  description = "-> variable de GitHub AWS_ROLE_ARN_PLAN (solo lectura, pull requests)"
  value       = aws_iam_role.plan.arn
}

output "aws_region" {
  description = "-> variable de GitHub AWS_REGION"
  value       = var.aws_region
}
