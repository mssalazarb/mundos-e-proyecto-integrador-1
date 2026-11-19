data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

# Falla en el plan si la imagen con ese tag no existe en ECR
data "aws_ecr_image" "app" {
  repository_name = data.aws_ecr_repository.app.name
  image_tag       = var.image_tag
}

resource "random_password" "grafana" {
  length  = 20
  special = false
}

locals {
  image = "${data.aws_ecr_repository.app.repository_url}:${data.aws_ecr_image.app.image_tag}"

  monitoring_dir = "${path.module}/../monitoring"
}

resource "aws_instance" "app" {
  ami                         = nonsensitive(data.aws_ssm_parameter.ubuntu_ami.value)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = true

  # Cada nueva imagen => nueva instancia (la IP elástica se conserva)
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    image            = local.image
    grafana_password = random_password.grafana.result
    prometheus_yml   = base64gzip(file("${local.monitoring_dir}/prometheus.yml"))
    datasource_yml   = base64gzip(file("${local.monitoring_dir}/grafana/provisioning/datasources/datasource.yml"))
    dashboards_yml   = base64gzip(file("${local.monitoring_dir}/grafana/provisioning/dashboards/dashboards.yml"))
    dashboard_json   = base64gzip(file("${local.monitoring_dir}/grafana/dashboards/passfly.json"))
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = { Name = "passfly-app" }

  lifecycle {
    # Una AMI nueva no debe recrear la instancia por sí sola
    ignore_changes = [ami]
  }
}

resource "aws_eip" "app" {
  domain = "vpc"

  tags = { Name = "passfly-app" }
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}
