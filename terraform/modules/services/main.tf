resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.dns_namespace_name
  description = "Private DNS namespace for internal microservices discovery"
  vpc         = var.vpc_id

  tags = {
    Name = "${var.project_name}-private-dns"
  }
}

resource "aws_service_discovery_service" "inventory_db" {
  name = "inventory-db-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${var.project_name}-discovery-inventory-db"
  }
}

resource "aws_service_discovery_service" "billing_db" {
  name = "billing-db-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${var.project_name}-discovery-billing-db"
  }
}

resource "aws_service_discovery_service" "rabbit_queue" {
  name = "rabbit-queue-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${var.project_name}-discovery-rabbit-queue"
  }
}

resource "aws_service_discovery_service" "inventory_app" {
  name = "inventory-app-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${var.project_name}-discovery-inventory-app"
  }
}

resource "aws_service_discovery_service" "api_gateway_app" {
  name = "api-gateway-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name = "${var.project_name}-discovery-api-gateway"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security Group for PostgreSQL database containers"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow PostgreSQL inbound from within VPC"
    from_port   = 5432
    to_port     = 5432
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
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Security Group for ECS Application Microservices"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow API Gateway traffic from within VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow Inventory and Billing service traffic from within VPC"
    from_port   = 8080
    to_port     = 8080
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
    Name = "${var.project_name}-app-sg"
  }
}
