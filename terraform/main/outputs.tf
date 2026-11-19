output "public_ip" {
  description = "IP elástica de la instancia"
  value       = aws_eip.app.public_ip
}

output "app_url" {
  description = "URL de PassFly"
  value       = "http://${aws_eip.app.public_ip}"
}

output "grafana_url" {
  description = "URL de Grafana (usuario: admin)"
  value       = "http://${aws_eip.app.public_ip}:3001"
}

output "grafana_admin_password" {
  description = "Contraseña de Grafana (terraform output -raw grafana_admin_password)"
  value       = random_password.grafana.result
  sensitive   = true
}

output "deployed_image" {
  description = "Imagen desplegada"
  value       = local.image
}

output "instance_id" {
  description = "ID de la instancia (acceso: aws ssm start-session --target <id>)"
  value       = aws_instance.app.id
}

output "image_tag" {
  description = "Tag desplegado actualmente (lo reutiliza el pipeline de solo-Terraform)"
  value       = var.image_tag
}
