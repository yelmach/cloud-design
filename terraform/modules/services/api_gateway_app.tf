resource "aws_ecs_task_definition" "api_gateway_app" {
  family                   = "${var.project_name}-api-gateway-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "api-gateway-app"
      image     = "${var.dockerhub_username}/api-gateway-app:latest"
      essential = true
      cpu       = 256
      memory    = 300

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "GATEWAY_HOST", value = "0.0.0.0" },
        { name = "GATEWAY_PORT", value = "3000" },
        { name = "INVENTORY_API_URL", value = "http://inventory-app-service.${var.dns_namespace_name}:8080" },
        { name = "RABBITMQ_HOST", value = "rabbit-queue-service.${var.dns_namespace_name}" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_DEFAULT_USER", value = var.rabbitmq_user },
        { name = "RABBITMQ_DEFAULT_PASS", value = var.rabbitmq_password },
        { name = "RABBITMQ_QUEUE", value = var.rabbitmq_queue }
      ]
    }
  ])

  tags = {
    Name = "${var.project_name}-api-gateway-app-td"
  }
}

resource "aws_ecs_service" "api_gateway_app" {
  name            = "${var.project_name}-api-gateway-app"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.api_gateway_app.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.app_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api_gateway_app.arn
  }

  tags = {
    Name = "${var.project_name}-api-gateway-app-service"
  }
}
