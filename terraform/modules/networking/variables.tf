variable "vpc_cidr" {
  description = "The CIDR block for the entire VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "azs" {
  description = "List of Availability Zones in the region"
  type        = list(string)
}

variable "project_name" {
  description = "The project name"
  type        = string
}
