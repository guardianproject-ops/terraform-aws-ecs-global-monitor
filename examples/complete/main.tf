data "aws_availability_zones" "this" {
  state = "available"
}

locals {
  availability_zones           = sort(slice(data.aws_availability_zones.this.names, 0, 2))
  rds_allow_access_cidr_blocks = concat(module.subnets.private_subnet_cidrs, module.subnets.public_subnet_cidrs)
}
################
# VPC
################

module "vpc" {
  source                           = "cloudposse/vpc/aws"
  version                          = "2.2.0"
  ipv4_primary_cidr_block          = var.vpc_cidr
  assign_generated_ipv6_cidr_block = false
  context                          = module.this.context
  attributes                       = ["vpc"]
}

module "subnets" {
  source                          = "cloudposse/dynamic-subnets/aws"
  version                         = "2.4.2"
  max_subnet_count                = 2
  availability_zones              = local.availability_zones
  vpc_id                          = module.vpc.vpc_id
  igw_id                          = [module.vpc.igw_id]
  ipv4_cidr_block                 = [var.subnets_cidr]
  ipv4_enabled                    = true
  ipv6_enabled                    = false
  nat_gateway_enabled             = false
  nat_instance_enabled            = false
  public_subnets_additional_tags  = { "Visibility" : "Public" }
  private_subnets_additional_tags = { "Visibility" : "Private" }
  metadata_http_endpoint_enabled  = true
  metadata_http_tokens_required   = true
  public_subnets_enabled          = true
  context                         = module.this.context
  attributes                      = ["vpc", "subnet"]
}

################
# RDS / DB
################

module "label_db" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  attributes = ["db"]
  context    = module.this.context
  enabled    = true
}

module "db" {
  source                              = "guardianproject-ops/rds-postgresql/aws"
  version                             = "0.0.2"
  context                             = module.label_db.context
  allocated_storage                   = 20
  allow_access_cidr_blocks            = local.rds_allow_access_cidr_blocks
  postgres_major_version              = "17"
  apply_immediately                   = true
  backup_retention_period             = 1
  deletion_protection_enabled         = false
  iam_database_authentication_enabled = true
  instance_class                      = "db.t3.medium"
  skip_final_snapshot                 = true
  alarms_enabled                      = false
  subnet_ids                          = concat(module.subnets.public_subnet_ids, module.subnets.private_subnet_ids)
  vpc_id                              = module.vpc.vpc_id
}

################
# Global Monitor
################

module "example" {
  source                             = "../.."
  context                            = module.this.context
  vpc_id                             = module.vpc.vpc_id
  public_subnet_ids                  = module.subnets.public_subnet_ids
  private_subnet_ids                 = module.subnets.private_subnet_ids
  global_monitor_acm_certificate_arn = ""
  db_global_monitor_host             = module.db.address
  db_global_monitor_name             = "global_monitor"
  rds_master_username                = module.db.admin_username
  # rds_resource_id                    = module.db.resource_id
  rds_master_user_secret_arn         = module.db.master_user_secret_arn
  global_monitor_frontend_node_count = 1
  global_monitor_api_node_count      = 1
  global_monitor_worker_node_count   = 1
  # this tailscale oidc client is used to create and auto-rotate an auth key for the tailscale ingress container
  # the oidc client should be created with no expiry date and with the same tags that you define below
  tailscale_client_id                     = var.tailscale_client_id
  tailscale_client_secret                 = var.tailscale_client_secret
  tailscale_tailnet                       = var.tailscale_tailnet
  tailscale_tags_global_monitor           = var.tailscale_tags_global_monitor
  deletion_protection_enabled             = false
  task_cpu                                = 2048
  task_memory                             = 4096
  global_monitor_frontend_container_image = "registry.gitlab.com/guardianproject/bypass-censorship/global-monitor-monorepo/frontend:main"
  global_monitor_api_container_image      = "registry.gitlab.com/guardianproject/bypass-censorship/global-monitor-monorepo/api:main"
  global_monitor_worker_container_image   = "registry.gitlab.com/guardianproject/bypass-censorship/global-monitor-monorepo/worker:main"
}

output "alb" {
  value = module.example.alb
}
