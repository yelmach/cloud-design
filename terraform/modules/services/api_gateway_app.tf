resource "aws_ecs_task_definition" "api_gateway_app" {
  family                   = "${var.project_name}-api-gateway-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "api-gateway-app"
      image     = "${var.dockerhub_username}/api-gateway-app:latest"
      essential = true
      cpu       = 256
      memory    = 300

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api-gateway"
        }
      }

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:3000/health')\" || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      environment = [
        { name = "GATEWAY_HOST", value = "0.0.0.0" },
        { name = "GATEWAY_PORT", value = "3000" },
        { name = "INVENTORY_API_URL", value = "http://inventory-app-service.${var.dns_namespace_name}:8080" },
        { name = "RABBITMQ_HOST", value = "rabbit-queue-service.${var.dns_namespace_name}" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_DEFAULT_USER", value = var.rabbitmq_user },
        { name = "RABBITMQ_QUEUE", value = var.rabbitmq_queue }
      ]

      secrets = [
        {
          name      = "RABBITMQ_DEFAULT_PASS"
          valueFrom = var.rabbitmq_password
        }
      ]
    }
  ])

  tags = {
    Name = "${var.project_name}-api-gateway-app-td"
  }
}

resource "aws_ecs_service" "api_gateway_app" {
  name                              = "${var.project_name}-api-gateway-app"
  cluster                           = var.ecs_cluster_id
  task_definition                   = aws_ecs_task_definition.api_gateway_app.arn
  desired_count                     = 1
  launch_type                       = "EC2"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.app_sg.id]
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "api-gateway-app"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api_gateway_app.arn
  }

  tags = {
    Name = "${var.project_name}-api-gateway-app-service"
  }
}
