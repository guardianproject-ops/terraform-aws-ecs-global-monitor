# This is ECS service that runs the global monitor itself
module "label_global_monitor" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.this.context
  attributes = ["global_monitor"]
}

locals {
  global_monitor_environment = [
    {
      name  = "HTTPS_CERTIFICATE_FILE"
      value = "/secrets/server.crt.pem"
    },
    {
      name  = "HTTPS_CERTIFICATE_KEY_FILE"
      value = "/secrets/server.key.pem"
    },
    {
      name  = "HTTPS_CERTIFICATES_RELOAD_PERIOD"
      value = "-1"
    },
    {
      name  = "DB_PASSWORD"
      value = var.db_global_monitor_password
    },
    {
      name  = "DB_ADDR"
      value = local.db_addr
    },
    {
      name  = "DB_USERNAME"
      value = var.db_global_monitor_user
    },
    {
      name  = "DB_SCHEMA"
      value = "public"
    },
  ]
}

# This is the container definition for global monitor frontend
module "global_monitor_frontend_def" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.1"

  container_name  = "global_monitor_frontend"
  container_image = var.global_monitor_frontend_container_image
  essential       = true

  mount_points = [
    {
      containerPath = "/secrets"
      readOnly      = true
      sourceVolume  = "global-monitor-secrets"
    }
  ]

  container_depends_on = [
    {
      condition     = "SUCCESS"
      containerName = "secrets-init"
    }
  ]

  secrets = []

  port_mappings = [
    {
      name          = "global-monitor-frontend"
      protocol      = "tcp",
      containerPort = local.port_global_monitor_frontend
      hostPort      = local.port_global_monitor_frontend
    }
  ]
  environment      = [for each in local.global_monitor_environment : each if each.value != null]
  linux_parameters = { initProcessEnabled = true }
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.global_monitor[0].name
      "awslogs-region"        = local.region
      "awslogs-stream-prefix" = "ecs"
    }
    secretOptions = null
  }
}

locals {
  container_def_postgres_init = {
    container_definition = module.postgres_init_sidecar[0].json_map_encoded
    condition            = "SUCCESS"
  }

  container_def_secrets_init = {
    container_definition = module.secrets_init_sidecar.json_map_encoded
    condition            = "SUCCESS"
  }
}

module "global_monitor_frontend" {
  source  = "guardianproject-ops/ecs-web-app/aws"
  version = "0.0.1"

  launch_type            = "FARGATE"
  vpc_id                 = var.vpc_id
  use_alb_security_group = true

  container_name       = "global_monitor_frontend"
  container_definition = module.global_monitor_frontend_def.json_map_encoded
  container_port       = local.port_global_monitor_frontend
  task_cpu             = var.task_cpu
  task_memory          = var.task_memory
  desired_count        = var.global_monitor_frontend_node_count

  init_containers = concat(
    var.rds_init_global_monitor_db ? [local.container_def_postgres_init] : [],
    [local.container_def_secrets_init]
  )

  bind_mount_volumes = [
    {
      name = "global-monitor-secrets"
    }
  ]


  exec_enabled                                    = var.exec_enabled
  ecs_alarms_enabled                              = false
  ecs_cluster_arn                                 = module.ecs_cluster.arn
  ecs_cluster_name                                = module.ecs_cluster.name
  ecs_security_group_ids                          = [aws_security_group.global_monitor[0].id]
  ecs_private_subnet_ids                          = var.public_subnet_ids
  assign_public_ip                                = true
  ignore_changes_task_definition                  = false
  alb_security_group                              = module.alb.security_group_id
  alb_target_group_alarms_enabled                 = true
  alb_target_group_alarms_3xx_threshold           = 25
  alb_target_group_alarms_4xx_threshold           = 25
  alb_target_group_alarms_5xx_threshold           = 25
  alb_target_group_alarms_response_time_threshold = 0.5
  alb_target_group_alarms_period                  = 300
  alb_target_group_alarms_evaluation_periods      = 1
  alb_arn_suffix                                  = module.alb.alb_arn_suffix
  alb_ingress_health_check_path                   = "/health/ready"
  alb_ingress_health_check_port                   = local.port_global_monitor_frontend
  alb_ingress_health_check_timeout                = 30
  alb_ingress_health_check_interval               = 60
  alb_ingress_health_check_protocol               = "HTTPS"
  alb_ingress_protocol                            = "HTTPS"
  health_check_grace_period_seconds               = 120
  # All paths are unauthenticated by default
  # Without authentication, both HTTP and HTTPS endpoints are supported
  alb_ingress_unauthenticated_listener_arns = [
    module.alb.http_listener_arn,
    module.alb.https_listener_arn,
  ]
  alb_ingress_unauthenticated_paths = []
  alb_stickiness_cookie_duration    = 24 * 60 * 60
  alb_stickiness_enabled            = true
  alb_stickiness_type               = "app_cookie"
  alb_stickiness_cookie_name        = "AUTH_SESSION_ID"

  service_connect_configurations = [{
    enabled   = true
    namespace = aws_service_discovery_http_namespace.this[0].arn
    service = [{
      discovery_name = "global-monitor-frontend"
      port_name      = "global-monitor-frontend"
      client_alias = [{
        dns_name = "global-monitor-frontend"
        port     = local.port_global_monitor_frontend
      }]
      },
    ]
  }]


  alb_target_group_alarms_alarm_actions             = var.alarms_sns_topics_arns
  alb_target_group_alarms_ok_actions                = var.alarms_sns_topics_arns
  alb_target_group_alarms_insufficient_data_actions = var.alarms_sns_topics_arns
  ecs_alarms_cpu_utilization_high_alarm_actions     = var.alarms_sns_topics_arns
  ecs_alarms_cpu_utilization_high_ok_actions        = var.alarms_sns_topics_arns
  ecs_alarms_memory_utilization_high_alarm_actions  = var.alarms_sns_topics_arns
  ecs_alarms_memory_utilization_high_ok_actions     = var.alarms_sns_topics_arns

  context = module.label_global_monitor.context
}

resource "aws_iam_role_policy_attachment" "global_monitor_exec" {
  role       = module.global_monitor_frontend.ecs_task_exec_role_name
  policy_arn = aws_iam_policy.global_monitor_exec.arn
}

resource "aws_iam_policy" "global_monitor_exec" {
  name   = "${module.label_global_monitor.id}-read-ssm-params"
  policy = data.aws_iam_policy_document.global_monitor_exec.json
}

data "aws_iam_policy_document" "global_monitor_exec" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "kms:Decrypt",
    ]
    resources = compact([
      # aws_ssm_parameter.global_monitor_password[0].arn,
      local.rds_master_user_secret_arn,
      aws_ssm_parameter.global_monitor_tls_cert[0].arn,
      aws_ssm_parameter.global_monitor_tls_key[0].arn,
      local.kms_key_arn
    ])
  }
}

resource "aws_iam_role_policy_attachment" "global_monitor_task" {
  count      = module.this.enabled ? 1 : 0
  role       = module.global_monitor_frontend.ecs_task_role_name
  policy_arn = aws_iam_policy.global_monitor_task[0].arn
}

resource "aws_iam_policy" "global_monitor_task" {
  count  = module.this.enabled ? 1 : 0
  name   = "${module.label_global_monitor.id}-global-monitor-task-perms"
  policy = data.aws_iam_policy_document.global_monitor_task.json
}

data "aws_iam_policy_document" "global_monitor_task_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "kms:Decrypt",
    ]
    resources = [
      aws_ssm_parameter.global_monitor_tls_cert[0].arn,
      aws_ssm_parameter.global_monitor_tls_key[0].arn,
      local.kms_key_arn
    ]
  }
}

data "aws_iam_policy_document" "global_monitor_task" {
  source_policy_documents = concat(
    [
      data.aws_iam_policy_document.global_monitor_task_secrets.json,
    ],
[],
  )
}
