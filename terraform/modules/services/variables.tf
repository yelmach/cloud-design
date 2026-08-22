variable "project_name" {
  description = "The project name"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  type        = string
}

variable "dockerhub_username" {
  description = "Docker Hub username for container images"
  type        = string
}

variable "dns_namespace_name" {
  description = "Private DNS namespace name for Service Discovery"
  type        = string
  default     = "cloud-design.local"
}

variable "inventory_db_name" {
  description = "Database name for the inventory service"
  type        = string
  default     = "inventory_db"
}

variable "inventory_db_user" {
  description = "Database user for the inventory service"
  type        = string
  default     = "inventory_user"
}

variable "inventory_db_password" {
  description = "Database password for the inventory service"
  type        = string
  default     = "password"
  sensitive   = true
}

variable "billing_db_name" {
  description = "Database name for the billing service"
  type        = string
  default     = "billing_db"
}

variable "billing_db_user" {
  description = "Database user for the billing service"
  type        = string
  default     = "billing_user"
}

variable "billing_db_password" {
  description = "Database password for the billing service"
  type        = string
  default     = "password"
  sensitive   = true
}

variable "rabbitmq_user" {
  description = "Default username for RabbitMQ"
  type        = string
  default     = "rabbit_user"
}

variable "rabbitmq_password" {
  description = "Default password for RabbitMQ"
  type        = string
  default     = "password"
  sensitive   = true
}

variable "rabbitmq_queue" {
  description = "Default queue name for RabbitMQ"
  type        = string
  default     = "billing_queue"
}

variable "cognito_user_pool_id" {
  description = "cognito_user_pool_id"
  type        = string
}
variable "cognito_client_id" {
  description = "cognito_client_id"
  type        = string
}
variable "cognito_issuer_url" {
  description = "cognito_issuer_url"
  type        = string
}
variable "ecs_execution_role_arn" {
  description = "ecs_execution_role_arn"
  type        = string
}
variable "ecs_task_role_arn" {
  description = "ecs_task_role_arn"
  type        = string
}
variable "alb_target_group_arn" {
  type = string
  description = "alb_target_group_arn"
}

variable "alb_listener_arn" {
  type = string
  description = "alb_target_group_arn"
}