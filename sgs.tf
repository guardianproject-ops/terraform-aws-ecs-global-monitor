resource "aws_security_group" "global_monitor" {
  count       = module.this.enabled ? 1 : 0
  name        = "${module.this.id}-global-monitor"
  description = "Security group for Global Monitor"
  vpc_id      = var.vpc_id
  tags        = merge(module.this.tags, { "Name" : "${module.this.id}-global-monitor" })
}

resource "aws_vpc_security_group_egress_rule" "global_monitor_egress_all" {
  count             = module.this.enabled ? 1 : 0
  security_group_id = aws_security_group.global_monitor[0].id
  ip_protocol       = "-1"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress traffic"
}

resource "aws_vpc_security_group_ingress_rule" "global_monitor_http" {
  count                        = module.this.enabled ? 1 : 0
  security_group_id            = aws_security_group.global_monitor[0].id
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = local.port_global_monitor_frontend
  to_port                      = local.port_global_monitor_frontend
  ip_protocol                  = "tcp"
  description                  = "Allow web ingress from ALB"
}

resource "aws_vpc_security_group_ingress_rule" "global_monitor_api" {
  count                        = module.this.enabled ? 1 : 0
  security_group_id            = aws_security_group.global_monitor[0].id
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = local.port_global_monitor_api
  to_port                      = local.port_global_monitor_api
  ip_protocol                  = "tcp"
  description                  = "Allow API ingress from ALB"
}

resource "aws_security_group" "alb" {
  count       = module.label_alb.enabled ? 1 : 0
  name        = "${module.this.id}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id
  tags        = merge(module.this.tags, { "Name" : "${module.this.id}-alb" })
}

resource "aws_vpc_security_group_egress_rule" "alb_egress_all" {
  count             = module.label_alb.enabled ? 1 : 0
  security_group_id = aws_security_group.alb[0].id
  ip_protocol       = "-1"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress traffic"
}
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count             = module.label_alb.enabled ? 1 : 0
  security_group_id = aws_security_group.alb[0].id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTP ingress"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = module.label_alb.enabled ? 1 : 0
  security_group_id = aws_security_group.alb[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS ingress"
}
