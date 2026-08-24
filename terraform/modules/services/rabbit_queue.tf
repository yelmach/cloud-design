resource "aws_ecs_task_definition" "rabbit_queue" {
  family                   = "${var.project_name}-rabbit-queue"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "rabbit-queue"
      image     = "rabbitmq:4-management-alpine"
      essential = true
      cpu       = 256
      memory    = 300

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "rabbit-queue"
        }
      }

      portMappings = [
        {
          containerPort = 5672
          hostPort      = 5672
          protocol      = "tcp"
        },
        {
          containerPort = 15672
          hostPort      = 15672
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "rabbitmq-diagnostics -q ping || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }

      environment = [
        { name = "RABBITMQ_DEFAULT_USER", value = var.rabbitmq_user },
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
    Name = "${var.project_name}-rabbit-queue-td"
  }
}

resource "aws_ecs_service" "rabbit_queue" {
  name            = "${var.project_name}-rabbit-queue"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.rabbit_queue.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.rabbitmq_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.rabbit_queue.arn
  }

  tags = {
    Name = "${var.project_name}-rabbit-queue-service"
  }
}
