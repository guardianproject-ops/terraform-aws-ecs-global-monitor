module "secrets_init_sidecar" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.1"

  container_name  = "secrets-init"
  container_image = "public.ecr.aws/aws-cli/aws-cli:2.22.12"
  essential       = false

  mount_points = [
    {
      containerPath = "/secrets"
      readOnly      = false
      sourceVolume  = "global-monitor-secrets"
    }
  ]

  environment = [
    {
      name  = "SSM_PARAM_CERT_B64"
      value = aws_ssm_parameter.global_monitor_tls_cert[0].arn
    },
    {
      name  = "SSM_PARAM_KEY_B64"
      value = aws_ssm_parameter.global_monitor_tls_key[0].arn
    }

  ]
  entrypoint = ["/bin/bash"]
  command = [
    "-c",
    <<-EOT
    set -ex -o pipefail
    aws ssm get-parameter \
        --with-decryption \
        --name "$${SSM_PARAM_CERT_B64}" \
        --query 'Parameter.Value' \
        --output text | base64 -d > /secrets/server.crt.pem

    aws ssm get-parameter \
        --with-decryption \
        --name "$${SSM_PARAM_KEY_B64}" \
        --query 'Parameter.Value' \
        --output text | base64 -d > /secrets/server.key.pem

    chown 1000:1000 /secrets/server.crt.pem
    chown 1000:1000 /secrets/server.key.pem
    chmod 644 /secrets/server.crt.pem
    chmod 600 /secrets/server.key.pem

    ls -al /secrets
    EOT
  ]

  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = local.region
      "awslogs-group"         = aws_cloudwatch_log_group.secrets_init[0].name
      "awslogs-region"        = local.region
      "awslogs-stream-prefix" = "ecs"
    }
  }
}
