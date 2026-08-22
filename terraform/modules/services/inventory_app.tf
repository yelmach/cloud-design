resource "aws_ecs_task_definition" "inventory_app" {
  family                   = "${var.project_name}-inventory-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "inventory-app"
      image     = "${var.dockerhub_username}/inventory-app:latest"
      essential = true
      cpu       = 256
      memory    = 300

       logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "eu-west-2"
          "awslogs-stream-prefix" = "inventory-app"
        }
      }

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "INVENTORY_HOST", value = "0.0.0.0" },
        { name = "INVENTORY_PORT", value = "8080" },
        { name = "INVENTORY_DB_HOST", value = "inventory-db-service.${var.dns_namespace_name}" },
        { name = "INVENTORY_DB_PORT", value = "5432" },
        { name = "INVENTORY_DB_NAME", value = var.inventory_db_name },
        { name = "INVENTORY_DB_USER", value = var.inventory_db_user },
      ]

      secrets = [
        {
          name      = "INVENTORY_DB_PASSWORD"
          valueFrom = var.inventory_db_password
        }
      ]
    }
  ])

  tags = {
    Name = "${var.project_name}-inventory-app-td"
  }
}

resource "aws_ecs_service" "inventory_app" {
  name            = "${var.project_name}-inventory-app"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.inventory_app.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.app_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.inventory_app.arn
  }

  tags = {
    Name = "${var.project_name}-inventory-app-service"
  }
}
