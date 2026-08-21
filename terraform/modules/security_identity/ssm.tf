resource "aws_ssm_parameter" "billing_db_password" {
  name        = "/app/billing_db/password"
  description = "RDS Database Master Password"
  type        = "SecureString"
  value       = var.billing_db_password

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-billing-db-password"
  }
}

resource "aws_ssm_parameter" "inventory_db_password" {
  name        = "/app/inventory_db/password"
  description = "RDS Database Master Password"
  type        = "SecureString"
  value       = var.inventory_db_password

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-inventory-db-password"
  }
}

resource "aws_ssm_parameter" "rabbitmq_password" {
  name        = "/app/rabbitmq/password"
  description = "RabbitMQ AMQP Connection Password"
  type        = "SecureString"
  value       = var.rabbitmq_password

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-rabbitmq-password"
  }
}