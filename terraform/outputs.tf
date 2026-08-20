output "vpc_id" {
  description = "The ID of the provisioned VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "dns_namespace_name" {
  description = "The domain name of the Private DNS Namespace for service discovery"
  value       = module.services.dns_namespace_name
}

output "inventory_db_endpoint" {
  description = "Internal service discovery endpoint for Inventory Database"
  value       = module.services.inventory_db_endpoint
}

output "billing_db_endpoint" {
  description = "Internal service discovery endpoint for Billing Database"
  value       = module.services.billing_db_endpoint
}

output "rabbit_queue_endpoint" {
  description = "Internal service discovery endpoint for RabbitMQ"
  value       = module.services.rabbit_queue_endpoint
}

output "inventory_app_endpoint" {
  description = "Internal service discovery endpoint for Inventory Application service"
  value       = module.services.inventory_app_endpoint
}

output "api_gateway_endpoint" {
  description = "Internal service discovery endpoint for API Gateway service"
  value       = module.services.api_gateway_endpoint
}


