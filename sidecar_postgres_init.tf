module "postgres_init_sidecar" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.1"

  count = module.this.enabled && var.rds_init_global_monitor_db ? 1 : 0

  container_name  = "postgres-init"
  container_image = "amazonlinux:latest"
  essential       = false

  #echo "Resetting database"
  #PGPASSWORD=$RDS_MASTER_PASSWORD psql -h $RDS_ENDPOINT -p $RDS_PORT \
  #  "sslmode=require dbname=postgres user=$RDS_MASTER_USERNAME" <<-EOF
  #  DROP DATABASE IF EXISTS "$RDS_GLOBAL_MONITOR_DB_NAME";
  #  DROP USER IF EXISTS "$RDS_GLOBAL_MONITOR_USERNAME";
  #EOF
  command = [
    "/bin/bash",
    "-c",
    <<-EOT
    set -ex -o pipefail

    echo "Postgres init container starting"
    echo "Installing dependencies..."
    yum update -y
    yum install -y postgresql16

    echo "Create global monitor user and associated database"
    echo "Note: Any message indicating that the user or the database already exists is informational and can be safely ignored."
    PGPASSWORD=$RDS_MASTER_PASSWORD psql -h $RDS_ENDPOINT -p $RDS_PORT \
      "sslmode=require dbname=postgres user=$RDS_MASTER_USERNAME" <<-EOF
        CREATE DATABASE "$RDS_GLOBAL_MONITOR_DB_NAME";
    EOF

    PGPASSWORD=$RDS_MASTER_PASSWORD psql -h $RDS_ENDPOINT -p $RDS_PORT \
      "sslmode=require dbname=$RDS_GLOBAL_MONITOR_DB_NAME user=$RDS_MASTER_USERNAME" <<-EOF
        CREATE USER "$RDS_GLOBAL_MONITOR_USERNAME" WITH LOGIN NOSUPERUSER CREATEDB CREATEROLE INHERIT;
        GRANT ALL PRIVILEGES ON DATABASE "$RDS_GLOBAL_MONITOR_DB_NAME" TO "$RDS_GLOBAL_MONITOR_USERNAME";
        GRANT ALL ON SCHEMA public TO "$RDS_GLOBAL_MONITOR_USERNAME";
        GRANT rds_iam TO "$RDS_GLOBAL_MONITOR_USERNAME";
    EOF
    EOT
  ]

  secrets = [
    {
      name      = "RDS_MASTER_PASSWORD"
      valueFrom = "${local.rds_master_user_secret_arn}:password::"
    }
  ]
  environment = [
    {
      name  = "RDS_ENDPOINT"
      value = local.db_addr
    },
    {
      name  = "RDS_PORT"
      value = local.db_port
    },
    {
      name  = "RDS_MASTER_USERNAME"
      value = local.rds_master_username
    },
    {
      name  = "RDS_GLOBAL_MONITOR_DB_NAME"
      value = var.db_global_monitor_name
    },
    {
      name  = "RDS_GLOBAL_MONITOR_USERNAME"
      value = var.db_global_monitor_user
    }
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = local.region
      "awslogs-group"         = aws_cloudwatch_log_group.postgres_init[0].name
      "awslogs-region"        = local.region
      "awslogs-stream-prefix" = "ecs"
    }
  }
}
