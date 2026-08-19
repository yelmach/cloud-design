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
