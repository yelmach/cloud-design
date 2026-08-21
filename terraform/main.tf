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
  source = "./modules/security_identity"

  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  vpc_cidr              = var.vpc_cidr
  private_subnet_ids    = module.networking.private_subnet_ids
  billing_db_password   = var.billing_db_password
  inventory_db_password = var.inventory_db_password
  rabbitmq_password     = var.rabbitmq_password
}

module "services" {
  source = "./modules/services"

  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.networking.private_subnet_ids
  ecs_cluster_id     = module.compute.ecs_cluster_arn
  dockerhub_username = var.dockerhub_username

  cognito_user_pool_id   = module.security_identity.user_pool_id
  cognito_client_id      = module.security_identity.user_pool_client_id
  cognito_issuer_url     = module.security_identity.cognito_issuer_url
  ecs_execution_role_arn = module.security_identity.ecs_execution_role_arn
  ecs_task_role_arn      = module.security_identity.ecs_task_role_arn

  alb_target_group_arn = module.security_identity.alb_target_group_arn

  billing_db_password = module.security_identity.ssm_billing_db_password_arn
  inventory_db_password = module.security_identity.ssm_inventory_db_password_arn
  rabbitmq_password = module.security_identity.ssm_rabbitmq_password_arn
}
