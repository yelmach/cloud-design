variable "region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "project_name" {
  description = "name of the project"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "azs" {
  description = "List of Availability Zones to use"
  type        = list(string)
}

variable "dockerhub_username" {
  description = "docker hub username"
  type        = string
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