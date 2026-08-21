module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
  project_name         = var.project_name
}

module "compute" {
  source = "./modules/compute"

  project_name       = var.project_name
  private_subnet_ids = module.networking.private_subnet_ids
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = var.vpc_cidr
}
module "security_identity" {
  source = "./module/security_identity"

  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.networking.private_subnet_ids
}

module "services" {
  source = "./modules/services"

  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.networking.private_subnet_ids
  ecs_cluster_id     = module.compute.ecs_cluster_arn
  dockerhub_username = var.dockerhub_username
}
