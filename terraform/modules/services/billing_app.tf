resource "aws_ecs_task_definition" "billing_app" {
  family                   = "${var.project_name}-billing-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "billing-app"
      image     = "${var.dockerhub_username}/billing-app:latest"
      essential = true
      cpu       = 256
      memory    = 300

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "BILLING_HOST", value = "0.0.0.0" },
        { name = "BILLING_PORT", value = "8080" },
        { name = "BILLING_DB_HOST", value = "billing-db-service.${var.dns_namespace_name}" },
        { name = "BILLING_DB_PORT", value = "5432" },
        { name = "BILLING_DB_NAME", value = var.billing_db_name },
        { name = "BILLING_DB_USER", value = var.billing_db_user },
        { name = "RABBITMQ_HOST", value = "rabbit-queue-service.${var.dns_namespace_name}" },
        { name = "RABBITMQ_PORT", value = "5672" },
        { name = "RABBITMQ_DEFAULT_USER", value = var.rabbitmq_user },
        { name = "RABBITMQ_QUEUE", value = var.rabbitmq_queue }
      ]
      secrets = [
        {
          name      = "RABBITMQ_DEFAULT_PASS"
          valueFrom = var.rabbitmq_password
        },
        {
          name      = "BILLING_DB_PASSWORD"
          valueFrom = var.billing_db_password
        }
      ]
    }
  ])

  tags = {
    Name = "${var.project_name}-billing-app-td"
  }
}

resource "aws_ecs_service" "billing_app" {
  name            = "${var.project_name}-billing-app"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.billing_app.arn
  desired_count   = 1
  launch_type     = "EC2"
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "${var.project_name}-billing-app-service"
  }
}
