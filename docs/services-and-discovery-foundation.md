# Services and Discovery Foundation

This document explains the service layer built for this project. It is written as a learning guide: it describes what each AWS and Terraform component is, why it is useful, and how it is used in this repository.

## What has been built

The services layer contains:

- Six ECS task definitions covering all microservices: `inventory-db`, `billing-db`, `inventory-app`, `billing-app`, `rabbit-queue`, and `api-gateway-app`.
- Six ECS services that keep the desired number of tasks running continuously.
- An AWS Cloud Map private DNS namespace for internal service discovery.
- Six Cloud Map service entries, one per microservice.
- Three security groups that control traffic between databases, applications, and the RabbitMQ broker.
- Application Auto Scaling policies for the stateless services.
- SSM Parameter Store secure parameters for database and RabbitMQ passwords.
- A CloudWatch log group shared by all container logs.

---

## ECS task definitions

### What is a task definition?

An **ECS task definition** is a blueprint for a container workload. It describes everything ECS needs to launch one or more containers as a unit: which image to use, how much CPU and memory to reserve, which ports to expose, how to handle logs, what environment variables to inject, and how to check if the container is healthy.

A task definition does not run anything by itself. It is a versioned template. An ECS service uses that template to launch actual running tasks.

This project defines one task definition per microservice. Each one targets the **EC2 launch type**, meaning ECS will schedule the task onto one of the EC2 container instances managed by the compute module.

### Network mode

All task definitions in this project use `network_mode = "awsvpc"`. In this mode, each task receives its own **Elastic Network Interface (ENI)** with a private IP address inside the VPC. This means:

- Each task has its own isolated network identity, separate from the EC2 host.
- Security group rules can be applied directly to the task, not just to the EC2 host.
- Two tasks declaring the same container port never conflict, because each has its own IP address.

### CPU and memory reservations

Each container reserves `600` CPU units and `600 MB` of memory (configured across task definitions in `terraform/modules/services/`). Total reservation across all six containers is 3,600 CPU units and 3,600 MB memory, which is comfortably distributed across the three `t3.small` EC2 hosts (each providing 2 vCPUs / 2,048 CPU units and 2 GB memory, totaling 6,144 CPU units and 6,144 MB memory for the cluster).

### Health checks

Every task definition includes a container-level health check. ECS polls this check at a regular interval and replaces the task if it fails repeatedly.

| Service | Health check command | Start period |
|---|---|---|
| `api-gateway-app` | HTTP request to `http://localhost:3000/health` | 30 s |
| `inventory-app` | HTTP request to `http://localhost:8080/health` | 30 s |
| `billing-app` | HTTP request to `http://localhost:8080/health` | 30 s |
| `inventory-db` | `pg_isready -U inventory_user -d inventory_db` | 60 s |
| `billing-db` | `pg_isready -U billing_user -d billing_db` | 60 s |
| `rabbit-queue` | `rabbitmq-diagnostics -q ping` | 60 s |

The start period delays the first check to allow the container to initialise before ECS begins evaluating it. Databases and RabbitMQ have a longer start period because they perform slower initialisation at first boot.

### Secrets injection

Passwords are not placed in environment variables directly. Instead, the task definitions reference SSM Parameter Store ARNs using the `secrets` block:

```hcl
secrets = [
  {
    name      = "POSTGRES_PASSWORD"
    valueFrom = var.billing_db_password  # SSM parameter ARN
  }
]
```

At task launch, the ECS agent calls SSM to retrieve the decrypted value and injects it into the container as an environment variable. The plaintext password is never stored in the task definition itself. The ECS task execution role has permission to read the `/app/*` namespace in SSM.

### Container logging

All containers use the `awslogs` log driver:

```hcl
logConfiguration = {
  logDriver = "awslogs"
  options = {
    "awslogs-group"         = "/ecs/cloud-design"
    "awslogs-region"        = var.aws_region
    "awslogs-stream-prefix" = "api-gateway"
  }
}
```

Every container sends its stdout and stderr to the shared `/ecs/cloud-design` CloudWatch log group. Each container gets its own log stream, prefixed by its service name (for example, `api-gateway/...`, `billing-app/...`). This keeps all service logs in one place and makes it easy to tail them with the AWS CLI.

---

## ECS services

### What is an ECS service?

An **ECS service** is a long-running controller that manages a task definition. It maintains a desired number of running tasks at all times. If a task exits unexpectedly or fails its health check, the service scheduler replaces it automatically.

This project defines one ECS service per microservice:

| Service | Desired count | Role |
|---|---:|---|
| `api-gateway-app` | 1 | Public entry point; attached to the Application Load Balancer |
| `inventory-app` | 1 | Movie CRUD API; communicates with inventory-db |
| `billing-app` | 1 | RabbitMQ consumer; writes to billing-db |
| `inventory-db` | 1 | PostgreSQL 16 database for inventory |
| `billing-db` | 1 | PostgreSQL 16 database for billing |
| `rabbit-queue` | 1 | RabbitMQ 4 message broker |

All services use `launch_type = "EC2"`, which places tasks on the container instances provided by the compute module.

### Health check grace period

The `api-gateway-app`, `billing-app`, and `inventory-app` ECS services set `health_check_grace_period_seconds = 60`. This gives the containers time to start before ECS evaluates their health status and considers replacing them. Without this, ECS might replace a healthy task that simply has not finished initialising yet.

### Load balancer attachment

Only `api-gateway-app` is attached to the Application Load Balancer. The `load_balancer` block in its ECS service definition registers the container's port `3000` as a target in the ALB target group. The ALB then sends incoming requests to whichever tasks are registered and healthy.

The other five services are internal; they are reached by other containers through Cloud Map service discovery rather than through the load balancer.

---

## AWS Cloud Map and service discovery

### What is service discovery?

In a microservices architecture, services need to find each other. In a traditional setup, you might hard-code IP addresses, but those change every time a container is replaced. **Service discovery** solves this by giving each service a stable DNS name that automatically resolves to the current task's IP address.

**AWS Cloud Map** is the service that manages this. This project uses its **private DNS namespace** feature, which creates DNS entries that are only resolvable inside the VPC.

### Private DNS namespace

The project creates one namespace named `cloud-design.local`:

```hcl
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "cloud-design.local"
  vpc  = var.vpc_id
}
```

This namespace is visible only within the VPC. Nothing outside the VPC can resolve names under `cloud-design.local`.

### Service discovery entries

Each microservice has a corresponding Cloud Map service entry:

| Cloud Map service name | Full DNS hostname | Resolves to |
|---|---|---|
| `inventory-db-service` | `inventory-db-service.cloud-design.local` | inventory-db task IP |
| `billing-db-service` | `billing-db-service.cloud-design.local` | billing-db task IP |
| `rabbit-queue-service` | `rabbit-queue-service.cloud-design.local` | rabbit-queue task IP |
| `inventory-app-service` | `inventory-app-service.cloud-design.local` | inventory-app task IP |
| `billing-app-service` | `billing-app-service.cloud-design.local` | billing-app task IP |
| `api-gateway-service` | `api-gateway-service.cloud-design.local` | api-gateway-app task IP |

Each entry uses `MULTIVALUE` routing and a 10-second DNS TTL. `MULTIVALUE` means the DNS response can include multiple IP addresses if multiple tasks are running — useful when auto-scaling creates additional tasks.

### How services use it

Environment variables inside each container reference these DNS names directly. For example, the `inventory-app` container receives:

```
INVENTORY_DB_HOST = inventory-db-service.cloud-design.local
INVENTORY_DB_PORT = 5432
```

And `api-gateway-app` reaches the inventory service and RabbitMQ with:

```
INVENTORY_API_URL = http://inventory-app-service.cloud-design.local:8080
RABBITMQ_HOST     = rabbit-queue-service.cloud-design.local
```

When a task is replaced, Cloud Map updates the DNS record to the new task's IP. The container using that name will get the new address on its next DNS lookup without any configuration change.

### service_registries block

Each ECS service includes a `service_registries` block that links the service to its Cloud Map entry:

```hcl
service_registries {
  registry_arn = aws_service_discovery_service.inventory_app.arn
}
```

When ECS launches a task, it automatically registers the task's private IP address in Cloud Map. When a task stops, ECS deregisters it. The developer does not need to manage DNS records manually.

---

## Security groups

### How the service layer is segmented

Three security groups provide network-level isolation between the different types of workload:

#### `app-sg` — Application microservices

This security group is attached to `api-gateway-app`, `inventory-app`, and `billing-app`.

| Direction | Rule | Purpose |
|---|---|---|
| Inbound | Port `3000` from ALB security group | Allows the ALB to reach the API gateway container |
| Inbound | Port `8080` from self | Allows the app containers to call each other on port 8080 |
| Outbound | All traffic to `0.0.0.0/0` | Allows outbound calls to databases, RabbitMQ, and the internet |

The self-referencing rule (`self = true`) means the security group allows traffic from other resources that also have this security group attached. This is how `api-gateway-app` can reach `inventory-app` — both share `app-sg`.

#### `db-sg` — PostgreSQL databases

This security group is attached to `inventory-db` and `billing-db`.

| Direction | Rule | Purpose |
|---|---|---|
| Inbound | Port `5432` from `app-sg` | Allows only app containers to connect to the database |
| Outbound | All traffic | Required for the database container to respond |

No other traffic is permitted into the database containers. A resource outside the VPC, or even a RabbitMQ container inside the VPC, cannot connect to PostgreSQL because it does not carry `app-sg`.

#### `rabbitmq-sg` — RabbitMQ broker

| Direction | Rule | Purpose |
|---|---|---|
| Inbound | Port `5672` (AMQP) from `app-sg` | Allows app containers to publish and consume messages |
| Inbound | Port `15672` (management UI) from VPC CIDR | Allows access to the RabbitMQ web dashboard from inside the VPC |
| Outbound | All traffic | Required for broker responses |

---

## Application Auto Scaling

### What is Application Auto Scaling?

**Application Auto Scaling** adjusts the desired count of an ECS service automatically based on observed metrics. Unlike the EC2 Auto Scaling group in the compute layer (which controls how many EC2 hosts exist), Application Auto Scaling controls how many **ECS tasks** run on those hosts.

The two are complementary: the ECS capacity provider can add EC2 hosts when the cluster is full, and Application Auto Scaling adds tasks when the service is under load.

### Scaling targets

Two services have scaling configured in this project:

| Service | Minimum tasks | Maximum tasks |
|---|---:|---:|
| `api-gateway-app` | 1 | 2 |
| `inventory-app` | 1 | 2 |

These are registered as **scalable targets** using `aws_appautoscaling_target`. The `resource_id` field links the target to the ECS service:

```hcl
resource_id = "service/${var.ecs_cluster_name}/${aws_ecs_service.api_gateway_app.name}"
```

### CPU-based scaling policy

Both services use a **Target Tracking Scaling** policy based on ECS average CPU utilisation:

| Service | Target CPU | Scale-out cooldown | Scale-in cooldown |
|---|---:|---:|---:|
| `api-gateway-app` | 80 % | 60 s | 300 s |
| `inventory-app` | 80 % | 60 s | 300 s |

**Target Tracking** works like a thermostat: AWS automatically adds tasks when CPU rises above the target and removes tasks when CPU falls back below it. The cooldown periods prevent rapid thrashing:

- A short **scale-out cooldown** (60 s) reacts quickly to sudden load spikes.
- A longer **scale-in cooldown** (300 s) avoids removing capacity too aggressively when load briefly drops.

### EC2 Auto Scaling group and the capacity provider

The compute module provisions an EC2 Auto Scaling group with a minimum of 3, desired capacity of 3, and a maximum of 4 hosts. The ECS capacity provider connects this ASG to the cluster and uses **managed scaling** to add or remove EC2 hosts as required:

```hcl
managed_scaling {
  status          = "ENABLED"
  target_capacity = 90
}
```

`target_capacity = 90` means ECS aims to keep host reservation close to 90 % of current demand — it adds a host before running out of capacity, rather than waiting until tasks cannot be placed. When Application Auto Scaling requests more tasks, the capacity provider can scale out the ASG to accommodate them.

---

## SSM Parameter Store

### What is SSM Parameter Store?

**AWS Systems Manager Parameter Store** is a managed service for storing configuration values and secrets. Parameters of type `SecureString` are encrypted using AWS Key Management Service (KMS). The values are never stored or transmitted in plaintext.

### How secrets are managed in this project

Three `SecureString` parameters are created:

| Parameter name | Contains |
|---|---|
| `/app/inventory_db/password` | PostgreSQL password for the inventory database |
| `/app/billing_db/password` | PostgreSQL password for the billing database |
| `/app/rabbitmq/password` | RabbitMQ default user password |

Each parameter uses `lifecycle { ignore_changes = [value] }`. This means Terraform creates the parameter with its initial value but will not overwrite it if the value has been changed outside Terraform. This allows an operator to rotate a password using the AWS CLI or console without Terraform reverting it on the next apply:

```bash
aws ssm put-parameter \
  --name /app/inventory_db/password \
  --value "new-strong-password" \
  --type SecureString \
  --overwrite
```

The ECS task execution role holds the `ecs-ssm-read-policy`, which allows `ssm:GetParameter`, `ssm:GetParameters`, and `ssm:GetParametersByPath` for the `/app/*` namespace. This is the minimum permission needed for ECS to inject secrets into task containers.

---

## CloudWatch log group

The log group `/ecs/cloud-design` receives all container logs from all six services. It is configured with a retention period of **7 days**, after which CloudWatch automatically deletes old log events. This prevents unbounded log storage costs in a learning environment.

Each container stream is prefixed by its service name, making it straightforward to filter logs for a single service:

```bash
aws logs tail /ecs/cloud-design \
  --region eu-west-2 \
  --log-stream-name-prefix billing-app \
  --follow
```

The log group is created in `services/main.tf` and referenced by all six task definitions. Creating it in Terraform (rather than letting ECS create it automatically) means the retention setting and tags are applied from the start.

---

## Estimated monthly cost additions

The figures below are approximate on-demand costs for services running continuously for 730 hours. AWS pricing varies by region and account type.

| Component | Estimated monthly cost | Explanation |
|---|---:|---|
| ECS service scheduling | $0.00 | ECS itself has no charge. Cost is in the underlying compute. |
| CloudWatch Logs ingestion | usage-dependent | Charged per GB of log data ingested and stored. Retention at 7 days limits storage cost. |
| CloudWatch dashboard | $0.00 | Up to 3 custom dashboards with up to 50 metrics per month are free in AWS Free Tier. [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) |
| SSM Parameter Store | $0.00 | Standard-tier `SecureString` parameters are free. |
| Cloud Map private DNS | $0.00 | Private DNS namespaces and Health Checks are free for the usage level in this project. [AWS Cloud Map pricing](https://aws.amazon.com/cloud-map/pricing/) |
| Application Auto Scaling | $0.00 | The auto-scaling service itself has no charge. |

---

## Useful commands

### View all ECS services and their health

```bash
aws ecs describe-services \
  --region eu-west-2 \
  --cluster cloud-design-cluster \
  --services \
    cloud-design-api-gateway-app \
    cloud-design-inventory-app \
    cloud-design-billing-app \
    cloud-design-inventory-db \
    cloud-design-billing-db \
    cloud-design-rabbit-queue \
  --query 'services[*].{Service:serviceName,Status:status,Desired:desiredCount,Running:runningCount}' \
  --output table
```

### Tail all service logs at once

```bash
aws logs tail /ecs/cloud-design --region eu-west-2 --follow
```

### Force a new deployment after pushing a new image

```bash
aws ecs update-service \
  --region eu-west-2 \
  --cluster cloud-design-cluster \
  --service cloud-design-api-gateway-app \
  --force-new-deployment
```

### Check Cloud Map registered instances

```bash
aws servicediscovery list-instances \
  --region eu-west-2 \
  --service-id <SERVICE_ID>
```
