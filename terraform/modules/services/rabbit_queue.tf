resource "aws_ecs_task_definition" "rabbit_queue" {
  family                   = "${var.project_name}-rabbit-queue"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "rabbit-queue"
      image     = "rabbitmq:4-management-alpine"
      essential = true
      cpu       = 256
      memory    = 300

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

      environment = [
        { name = "RABBITMQ_DEFAULT_USER", value = var.rabbitmq_user },
        { name = "RABBITMQ_DEFAULT_PASS", value = var.rabbitmq_password }
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

resource "aws_security_group" "rabbitmq_sg" {
  name        = "${var.project_name}-rabbitmq-sg"
  description = "Security Group for RabbitMQ messaging broker"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow AMQP traffic from within VPC"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow RabbitMQ Management UI from within VPC"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rabbitmq-sg"
  }
}
