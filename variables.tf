variable "aws_region" {
    description = "AWS region to deploy to"
    type = string
    default = "eu-west-3"
}

variable "project_name" {
  description = "Prefix used to name/tag all resources"
  type        = string
  default     = "cloud-design"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  default     = ["eu-west-3a"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24"]
}

variable "private_db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.20.0/24"]
}