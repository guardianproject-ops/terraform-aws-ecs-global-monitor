# This is ECS service that runs tailscale as an HTTP ingress
# that is only accessible for the tailnet
module "label_tailscale" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.this.context
  attributes = ["tailscale", "ingress"]
}

module "service_tailscale" {
  source                       = "guardianproject-ops/ecs-service-tailscale/aws"
  version                      = "0.0.1"
  context                      = module.label_tailscale.context
  vpc_id                       = var.vpc_id
  kms_key_arn                  = local.kms_key_arn
  private_subnet_ids           = var.private_subnet_ids
  public_subnet_ids            = var.public_subnet_ids
  tailscale_container_image    = var.tailscale_container_image
  tailscale_serve_enabled      = true
  tailscale_serve_upstream_url = "https+insecure://global-monitor-frontend:${local.port_global_monitor_frontend}"
  tailscale_tags               = var.tailscale_tags_global_monitor
  tailscale_tailnet            = var.tailscale_tailnet
  tailscale_client_id          = var.tailscale_client_id
  tailscale_client_secret      = var.tailscale_client_secret
  ecs_cluster_arn              = module.ecs_cluster.arn

  # the container uses service connect to be able to dynamically reference the global monitor containers by dns "global-monitor-frontend"
  service_connect_configurations = [{
    enabled   = true
    namespace = aws_service_discovery_http_namespace.this[0].arn
    service   = []
  }]
}
