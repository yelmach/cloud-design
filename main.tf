module "network" {
  source                   = "./modules/network"
  vpc_cidr                 = var.vpc_cidr
  azs                      = var.azs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  project_name             = var.project_name
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}
