# Sin SSH: la administración se hace con SSM Session Manager.
resource "aws_security_group" "app" {
  name_prefix = "passfly-app-"
  description = "PassFly: web publica, Grafana restringido"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "passfly-app" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "PassFly (HTTP)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "grafana" {
  security_group_id = aws_security_group.app.id
  description       = "Grafana (solo admin_cidr)"
  ip_protocol       = "tcp"
  from_port         = 3001
  to_port           = 3001
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Salida a internet (paquetes, ECR, imagenes Docker)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
