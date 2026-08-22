resource "aws_ecs_task_definition" "billing_db" {
  family                   = "${var.project_name}-billing-db"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "billing-db"
      image     = "postgres:16-alpine"
      essential = true
      cpu       = 256
      memory    = 300

       logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "eu-west-2"
          "awslogs-stream-prefix" = "billing-db"
        }
      }

      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "POSTGRES_DB", value = var.billing_db_name },
        { name = "POSTGRES_USER", value = var.billing_db_user },
      ]
      secrets = [
        {
          name = "POSTGRES_PASSWORD"
          valueFrom = var.billing_db_password 
        }
      ]
    }
  ])

  tags = {
    Name = "${var.project_name}-billing-db-td"
  }
}

resource "aws_ecs_service" "billing_db" {
  name            = "${var.project_name}-billing-db"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.billing_db.arn
  desired_count   = 1
  launch_type     = "EC2"


  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.db_sg.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.billing_db.arn
  }

  tags = {
    Name = "${var.project_name}-billing-db-service"
  }
}
