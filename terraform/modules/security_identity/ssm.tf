
resource "aws_ssm_parameter" "db_host" {
  name        = "/app/db/host"
  description = "RDS Database Endpoint Hostname"
  type        = "String"
  value       = "db-endpoint.internal"

  lifecycle {
    ignore_changes = [value] 
  }

  tags = {
    Name        = "${var.project_name}-db-host"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/app/db/password"
  description = "RDS Database Master Password"
  type        = "SecureString"
  value       = "db_password"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-db-password"
  }
}

resource "aws_ssm_parameter" "rabbitmq_url" {
  name        = "/app/rabbitmq/url"
  description = "RabbitMQ AMQP Connection String"
  type        = "SecureString"
  value       = "amqp://guest:guest@placeholder-rabbitmq:5672"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-rabbitmq-url"
  }
}