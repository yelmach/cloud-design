output "dns_namespace_id" {
  description = "The ID of the Private DNS Namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "dns_namespace_name" {
  description = "The domain name of the Private DNS Namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "inventory_db_endpoint" {
  description = "Internal discovery hostname for inventory database"
  value       = "inventory-db-service.${var.dns_namespace_name}"
}

output "billing_db_endpoint" {
  description = "Internal discovery hostname for billing database"
  value       = "billing-db-service.${var.dns_namespace_name}"
}

output "rabbit_queue_endpoint" {
  description = "Internal discovery hostname for RabbitMQ"
  value       = "rabbit-queue-service.${var.dns_namespace_name}"
}

output "inventory_app_endpoint" {
  description = "Internal discovery hostname for Inventory Application service"
  value       = "inventory-app-service.${var.dns_namespace_name}"
}

output "api_gateway_endpoint" {
  description = "Internal discovery hostname for API Gateway service"
  value       = "api-gateway-service.${var.dns_namespace_name}"
}

output "db_security_group_id" {
  description = "The ID of the database security group"
  value       = aws_security_group.db_sg.id
}

output "rabbitmq_security_group_id" {
  description = "The ID of the RabbitMQ security group"
  value       = aws_security_group.rabbitmq_sg.id
}

output "app_security_group_id" {
  description = "The ID of the application security group"
  value       = aws_security_group.app_sg.id
}
