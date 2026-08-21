variable "project_name" {
  description = "name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

variable "vpc_cidr" {
  description = "vpc cidr"
  type        = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "The privates subnet IDs passed from the network module"
}

variable "billing_db_password" {
  description = "billing_db_password"
  type = string
}

variable "inventory_db_password" {
  description = "inventory_db_password"
  type = string
}

variable "rabbitmq_password" {
  description = "rabbitmq_password"
  type = string
}