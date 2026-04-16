module "network" {
  source               = "../../modules/network"
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
}

module "iam" {
  source = "../../modules/iam"
}

module "ecr" {
  source = "../../modules/ecr"
}

module "storage" {
  source = "../../modules/storage"
}

module "compute" {
  source               = "../../modules/compute"
  cluster_name         = var.cluster_name
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_role_arn    = module.iam.eks_node_role_arn
}

module "database" {
  source                     = "../../modules/database"
  vpc_id                     = module.network.vpc_id
  private_subnet_ids         = module.network.private_subnet_ids
  eks_node_security_group_id = module.compute.node_security_group_id
  db_username                = var.db_username
  db_password                = var.db_password
}

module "rabbitmq" {
  source                        = "../../modules/rabbitmq"
  rabbitmq_password             = var.rabbitmq_password
  rabbitmq_wait                 = false
  rabbitmq_timeout              = 300
  rabbitmq_service_type         = "ClusterIP"
  rabbitmq_persistence_enabled  = false
  rabbitmq_metrics_enabled      = false
  rabbitmq_requests_cpu         = "50m"
  rabbitmq_requests_memory      = "128Mi"
  rabbitmq_limits_cpu           = "250m"
  rabbitmq_limits_memory        = "256Mi"
  depends_on                    = [module.compute]
}

module "dns" {
  source         = "../../modules/dns"
  hosted_zone_id = var.hosted_zone_id
  depends_on     = [module.compute]
}
