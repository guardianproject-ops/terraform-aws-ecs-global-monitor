variable "vpc_id" {
  type        = string
  description = "The VPC id ECS will be deployed into"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = <<EOT
The ids for the public subnets that ECS will be deployed into
EOT
}

variable "private_subnet_ids" {
  type        = list(string)
  description = <<EOT
The ids for the private subnets that EFS will be deployed into
EOT
}

variable "log_group_retention_in_days" {
  default     = 30
  type        = number
  description = <<EOT
The number in days that cloudwatch logs will be retained.
EOT
}

variable "tailscale_container_image" {
  type        = string
  default     = "ghcr.io/tailscale/tailscale:stable"
  description = <<EOT
The fully qualified container image for tailscale.
EOT
}

variable "global_monitor_frontend_container_image" {
  type        = string
  default     = "registry.gitlab.com/guardianproject/bypass-censorship/global-monitor-monorepo/frontend:main"
  description = <<EOT
The fully qualified container image for global monitor frontend.
EOT
}

variable "global_monitor_api_container_image" {
  type        = string
  default     = "registry.gitlab.com/guardianproject/bypass-censorship/global-monitor-monorepo/api:main"
  description = <<EOT
The fully qualified container image for global monitor api.
EOT
}

variable "global_monitor_worker_container_image" {
  type        = string
  default     = "registry.gitlab.com/guardianproject/bypass-censorship/global-monitor-monorepo/worker:main"
  description = <<EOT
The fully qualified container image for global monitor worker.
EOT
}

variable "kms_key_arn" {
  type        = string
  description = "The kms key ARN used for various purposes throughout the deployment, if not provided a kms key will be created. This is difficult to change later."
  default     = null
}

variable "global_monitor_frontend_node_count" {
  type        = number
  description = "The number of global monitor frontend containers to run"
  default     = 1
}

variable "global_monitor_api_node_count" {
  type        = number
  description = "The number of global monitor api containers to run"
  default     = 1
}

variable "global_monitor_worker_node_count" {
  type        = number
  description = "The number of global monitor worker containers to run"
  default     = 1
}

variable "tailscale_tags_global_monitor" {
  type = list(string)

  description = "The list of tags that will be assigned to tailscale node created by this stack."
  validation {
    condition = alltrue([
      for tag in var.tailscale_tags_global_monitor : can(regex("^tag:", tag))
    ])
    error_message = "max_allocated_storage: Each tag in tailscale_tags_global_monitor must start with 'tag:'"
  }
}

variable "tailscale_tailnet" {
  type = string

  description = <<EOT
  description = The tailnet domain (or "organization's domain") for your tailscale tailnet, this s found under Settings > General > Organization
EOT
}

variable "tailscale_client_id" {
  type        = string
  sensitive   = true
  description = "The OIDC client id for tailscale that has permissions to create auth keys with the `tailscale_tags_global_monitor` tags"
}

variable "tailscale_client_secret" {
  type        = string
  sensitive   = true
  description = "The OIDC client secret paired with `tailscale_client_id`"
}

variable "task_cpu_global_monitor_api" {
  type        = number
  description = "The number of CPU units used by the API task.  If using `FARGATE` launch type `task_cpu` must match supported memory values (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
}

variable "task_memory_global_monitor_api" {
  type        = number
  description = "The amount of memory (in MiB) used by the API task. If using Fargate launch type `task_memory` must match supported cpu value (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
}

variable "task_cpu_global_monitor_frontend" {
  type        = number
  description = "The number of CPU units used by the FRONTEND task.  If using `FARGATE` launch type `task_cpu` must match supported memory values (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
}

variable "task_memory_global_monitor_frontend" {
  type        = number
  description = "The amount of memory (in MiB) used by the FRONTEND task. If using Fargate launch type `task_memory` must match supported cpu value (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
}

variable "task_cpu_global_monitor_worker" {
  type        = number
  description = "The number of CPU units used by the WORKER task.  If using `FARGATE` launch type `task_cpu` must match supported memory values (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
}

variable "task_memory_global_monitor_worker" {
  type        = number
  description = "The amount of memory (in MiB) used by the WORKER task. If using Fargate launch type `task_memory` must match supported cpu value (https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size)"
}

variable "global_monitor_acm_certificate_arn" {
  type        = string
  description = <<EOT
The arn for the ACM certificate used to provide TLS for your global monitor instance
EOT
}

variable "rds_init_global_monitor_db" {
  type        = bool
  default     = true
  description = <<EOT
If true then the postgresql database for global monitor will be initialized using the RDS master credentials
EOT
}

variable "rds_master_username" {
  type        = string
  default     = ""
  description = <<EOT
The username of the RDS master user
EOT

  validation {
    condition     = var.rds_init_global_monitor_db == true ? length(var.rds_master_username) > 1 : true
    error_message = "When initialzing the RDS instance with a global monitor user and db, you must specific the var.rds_master_username"
  }
}

variable "rds_master_user_secret_arn" {
  type        = string
  default     = null
  description = <<EOT
If true then the postgresql database for global monitor will be initialized using the RDS master credentials
EOT

  validation {
    condition     = var.rds_init_global_monitor_db == true ? var.rds_master_user_secret_arn != null : true
    error_message = "When initialzing the RDS instance with a global monitor user and db, you must specific the var.rds_master_user_secret_arn"
  }
}

variable "db_global_monitor_user" {
  type        = string
  default     = "global_monitor"
  description = "The password for the global monitor account on the postgres instance"
}

variable "db_global_monitor_name" {
  type        = string
  default     = "global_monitor"
  description = <<EOT
The postgresql db name for global monitor
EOT
}
variable "db_global_monitor_port" {
  type        = number
  default     = 5432
  description = <<EOT
The postgresql port number for global monitor
EOT
}

variable "db_global_monitor_host" {
  type        = string
  description = <<EOT
The postgresql host for global monitor
EOT
}

variable "db_global_monitor_password" {
  type        = string
  default     = null
  description = <<EOT
The postgresql password for global monitor, when not using IAM authentication
EOT
}

variable "port_global_monitor_frontend" {
  type        = number
  default     = 3000
  description = <<EOT
The port number for global monitor frontend
EOT
}

variable "port_global_monitor_api" {
  type        = number
  default     = 3000
  description = <<EOT
The port number for global monitor api
EOT
}

variable "deletion_protection_enabled" {
  type        = bool
  description = "Whether or not to enable deletion protection on things that support it"
  default     = true
}

variable "alarms_sns_topics_arns" {
  type        = list(string)
  default     = []
  description = "A list of SNS topic arns that will be the actions for cloudwatch alarms"
}

variable "exec_enabled" {
  type        = bool
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service"
  default     = false
}
