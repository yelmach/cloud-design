Here is a comprehensive `README.md` guide containing all the CLI commands required to provision, manage, inspect, and audit your AWS microservices platform.

---

# AWS Microservices Platform — Operational & Audit CLI Reference

This document provides a complete CLI reference for managing the containerized AWS microservices platform. It covers Infrastructure as Code (IaC), secret management, edge authentication, container orchestration, live log streaming, private instance access, and the exact steps required for the project audit evaluation.

---

## 1. Infrastructure as Code (Terraform)

Provision, inspect, and manage the underlying AWS infrastructure using Terraform.

```bash
# Initialize working directory and download provider plugins[cite: 33]
terraform init

# Recursively format all configuration files
terraform fmt -recursive

# Validate code syntax and module wiring
terraform validate

# Preview infrastructure execution plan[cite: 35]
terraform plan

# Apply infrastructure changes[cite: 35]
terraform apply -auto-approve

# View all environment outputs
terraform output

# Extract a specific raw output value
terraform output -raw api_gateway_url

# Destroy all provisioned cloud resources[cite: 33]
terraform destroy -auto-approve

```

---

## 2. Secrets Management (AWS SSM Parameter Store)

Manage encrypted database and messaging credentials dynamically in AWS Systems Manager.

```bash
# Store or overwrite sensitive credentials in SSM Parameter Store[cite: 33, 34]
aws ssm put-parameter \
  --name "/app/inventory_db/password" \
  --value "SuperSecureInvPass123!" \
  --type "SecureString" \
  --overwrite[cite: 33, 34]

aws ssm put-parameter \
  --name "/app/billing_db/password" \
  --value "SuperSecureBillPass123!" \
  --type "SecureString" \
  --overwrite[cite: 33, 34]

aws ssm put-parameter \
  --name "/app/rabbitmq/password" \
  --value "SuperSecureRabbitPass123!" \
  --type "SecureString" \
  --overwrite[cite: 33, 34]

# Retrieve and decrypt a stored parameter[cite: 34]
aws ssm get-parameter \
  --name "/app/billing_db/password" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text[cite: 34]

```

---

## 3. Managed Authentication & Token Issuance (AWS Cognito)

Create and authenticate users using AWS Cognito to obtain JWT tokens for API Gateway authorization.

```bash
# 1. Register a new user in the Cognito User Pool[cite: 33, 34]
aws cognito-idp sign-up \
  --client-id <COGNITO_CLIENT_ID> \
  --username "test@cloud.design" \
  --password "Test1234*" \
  --user-attributes Name="email",Value="test@cloud.design"[cite: 33, 34]

# 2. Admin-confirm user account (bypasses email verification code)[cite: 34]
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id <COGNITO_USER_POOL_ID> \
  --username "test@cloud.design"[cite: 34]

# 3. Authenticate and issue a JWT ID token[cite: 34]
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <COGNITO_CLIENT_ID> \
  --auth-parameters USERNAME="test@cloud.design",PASSWORD="Test1234*" \
  --query "AuthenticationResult.IdToken" \
  --output text[cite: 34]

```

---

## 4. Container Orchestration & Service Control (AWS ECS)

Inspect running container tasks, monitor cluster health, and control service scaling.

```bash
# List all running task ARNs in the cluster[cite: 35]
aws ecs list-tasks --cluster cloud-design-cluster[cite: 35]

# Describe status across all core microservices[cite: 35]
aws ecs describe-services \
  --cluster cloud-design-cluster \
  --services cloud-design-api-gateway-app cloud-design-inventory-app cloud-design-inventory-db cloud-design-billing-app cloud-design-billing-db cloud-design-rabbit-queue \
  --query "services[*].{Name:serviceName, Status:status, Running:runningCount, Desired:desiredCount}" \
  --output table[cite: 35]

# Inspect detailed task container properties and host placement[cite: 34, 35]
aws ecs describe-tasks \
  --cluster cloud-design-cluster \
  --tasks <TASK_ARN>[cite: 34, 35]

# Scale a service desired count (e.g., stop the billing app)[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 0[cite: 35]

# Restart a service desired count[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 1[cite: 35]

# Force a container deployment refresh[cite: 33]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --force-new-deployment[cite: 33]

```

---

## 5. Live Monitoring & Log Analytics (AWS CloudWatch)

Stream real-time stdout/stderr log streams from all ECS tasks.

```bash
# Tail live log streams across all microservices[cite: 34]
aws logs tail /ecs/cloud-design --follow[cite: 34]

# Tail API Gateway microservice logs specifically[cite: 34]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "api-gateway" --follow[cite: 34]

# Tail RabbitMQ message broker logs[cite: 34]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "rabbit-queue" --follow[cite: 34]

# Tail Billing microservice logs[cite: 34]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "billing-app" --follow[cite: 34]

```

---

## 6. Private Host Access & Database Shells (SSM Session Manager)

Securely access private EC2 container hosts and query PostgreSQL databases without exposing public ports.

```bash
# 1. Identify running EC2 host instances[cite: 34, 35]
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text[cite: 34]

# 2. Open an interactive shell on a private EC2 host instance[cite: 34]
aws ssm start-session --target <EC2_INSTANCE_ID>[cite: 34]

# ------------------------------------------------------------------------------
# Executed INSIDE the EC2 Host Terminal Session:
# ------------------------------------------------------------------------------

# List running Docker containers on the host[cite: 35]
sudo docker ps[cite: 35]

# Connect to the Billing PostgreSQL database[cite: 33]
sudo docker exec -it <BILLING_DB_CONTAINER_ID> psql -U billing_user -d billing_db[cite: 33]

# Connect to the Inventory PostgreSQL database[cite: 33]
sudo docker exec -it <INVENTORY_DB_CONTAINER_ID> psql -U inventory_user -d inventory_db[cite: 33]

# Useful psql queries:
# \dt                      --> List tables
# SELECT * FROM movies;    --> Query records
# \q                       --> Exit psql

```

---

## 7. Audit Demonstration & Resilience Procedures

Perform the official validation suite required by the project auditor.

### Step 1: Unauthenticated Endpoint Test (Expect `401 Unauthorized`)

```bash
# Request sent without Bearer token must be rejected at API Gateway edge[cite: 33, 35]
curl -i https://<API_GATEWAY_URL>/movies[cite: 35]

```

### Step 2: Authenticated CRUD Operations

```bash
# Create a new record (POST)[cite: 35]
curl -i -X POST https://<API_GATEWAY_URL>/movies \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Interstellar", "director": "Christopher Nolan"}'[cite: 35]

# Retrieve records (GET)[cite: 35]
curl -i -H "Authorization: Bearer <JWT_TOKEN>" https://<API_GATEWAY_URL>/movies[cite: 35]

```

### Step 3: Message Queue Resilience Test (Billing Outage)

```bash
# 1. Stop the downstream billing service[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 0[cite: 35]

# 2. Send a billing request (Enqueued into RabbitMQ without failing at edge)[cite: 33, 35]
curl -i -X POST https://<API_GATEWAY_URL>/billing \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "usr_77", "amount": 89.99}'[cite: 35]

# 3. Restart the billing consumer service[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 1[cite: 35]

# 4. Stream consumer logs to verify automatic consumption of queued messages[cite: 34, 35]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "billing-app" --follow[cite: 34, 35]

```

---

## 8. Helper Script: Service-to-Host Mapping

Run this one-liner to map every ECS microservice directly to its hosting EC2 instance ID:

```bash
for SERVICE in cloud-design-api-gateway-app cloud-design-inventory-app cloud-design-inventory-db cloud-design-billing-app cloud-design-billing-db cloud-design-rabbit-queue; do
  TASK_ARN=$(aws ecs list-tasks --cluster cloud-design-cluster --service-name $SERVICE --query "taskArns[0]" --output text 2>/dev/null)
  if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    CI_ARN=$(aws ecs describe-tasks --cluster cloud-design-cluster --tasks $TASK_ARN --query "tasks[0].containerInstanceArn" --output text)
    EC2_ID=$(aws ecs describe-container-instances --cluster cloud-design-cluster --container-instances $CI_ARN --query "containerInstances[0].ec2InstanceId" --output text)
    echo "Service: $SERVICE ---> EC2 Host: $EC2_ID"
  else
    echo "Service: $SERVICE ---> (Not Running / Scaled to 0)"
  fi
done[cite: 34, 35]

```


Here is a comprehensive `README.md` guide containing all the CLI commands required to provision, manage, inspect, and audit your AWS microservices platform.

---

# AWS Microservices Platform — Operational & Audit CLI Reference

This document provides a complete CLI reference for managing the containerized AWS microservices platform. It covers Infrastructure as Code (IaC), secret management, edge authentication, container orchestration, live log streaming, private instance access, and the exact steps required for the project audit evaluation.

---

## 1. Infrastructure as Code (Terraform)

Provision, inspect, and manage the underlying AWS infrastructure using Terraform.

```bash
# Initialize working directory and download provider plugins[cite: 33]
terraform init

# Recursively format all configuration files
terraform fmt -recursive

# Validate code syntax and module wiring
terraform validate

# Preview infrastructure execution plan[cite: 35]
terraform plan

# Apply infrastructure changes[cite: 35]
terraform apply -auto-approve

# View all environment outputs
terraform output

# Extract a specific raw output value
terraform output -raw api_gateway_url

# Destroy all provisioned cloud resources[cite: 33]
terraform destroy -auto-approve

```

---

## 2. Secrets Management (AWS SSM Parameter Store)

Manage encrypted database and messaging credentials dynamically in AWS Systems Manager.

```bash
# Store or overwrite sensitive credentials in SSM Parameter Store[cite: 33, 34]
aws ssm put-parameter \
  --name "/app/inventory_db/password" \
  --value "SuperSecureInvPass123!" \
  --type "SecureString" \
  --overwrite[cite: 33, 34]

aws ssm put-parameter \
  --name "/app/billing_db/password" \
  --value "SuperSecureBillPass123!" \
  --type "SecureString" \
  --overwrite[cite: 33, 34]

aws ssm put-parameter \
  --name "/app/rabbitmq/password" \
  --value "SuperSecureRabbitPass123!" \
  --type "SecureString" \
  --overwrite[cite: 33, 34]

# Retrieve and decrypt a stored parameter[cite: 34]
aws ssm get-parameter \
  --name "/app/billing_db/password" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text[cite: 34]

```

---

## 3. Managed Authentication & Token Issuance (AWS Cognito)

Create and authenticate users using AWS Cognito to obtain JWT tokens for API Gateway authorization.

```bash
# 1. Register a new user in the Cognito User Pool[cite: 33, 34]
aws cognito-idp sign-up \
  --client-id <COGNITO_CLIENT_ID> \
  --username "test@cloud.design" \
  --password "Test1234*" \
  --user-attributes Name="email",Value="test@cloud.design"[cite: 33, 34]

# 2. Admin-confirm user account (bypasses email verification code)[cite: 34]
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id <COGNITO_USER_POOL_ID> \
  --username "test@cloud.design"[cite: 34]

# 3. Authenticate and issue a JWT ID token[cite: 34]
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <COGNITO_CLIENT_ID> \
  --auth-parameters USERNAME="test@cloud.design",PASSWORD="Test1234*" \
  --query "AuthenticationResult.IdToken" \
  --output text[cite: 34]

```

---

## 4. Container Orchestration & Service Control (AWS ECS)

Inspect running container tasks, monitor cluster health, and control service scaling.

```bash
# List all running task ARNs in the cluster[cite: 35]
aws ecs list-tasks --cluster cloud-design-cluster[cite: 35]

# Describe status across all core microservices[cite: 35]
aws ecs describe-services \
  --cluster cloud-design-cluster \
  --services cloud-design-api-gateway-app cloud-design-inventory-app cloud-design-inventory-db cloud-design-billing-app cloud-design-billing-db cloud-design-rabbit-queue \
  --query "services[*].{Name:serviceName, Status:status, Running:runningCount, Desired:desiredCount}" \
  --output table[cite: 35]

# Inspect detailed task container properties and host placement[cite: 34, 35]
aws ecs describe-tasks \
  --cluster cloud-design-cluster \
  --tasks <TASK_ARN>[cite: 34, 35]

# Scale a service desired count (e.g., stop the billing app)[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 0[cite: 35]

# Restart a service desired count[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 1[cite: 35]

# Force a container deployment refresh[cite: 33]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --force-new-deployment[cite: 33]

```

---

## 5. Live Monitoring & Log Analytics (AWS CloudWatch)

Stream real-time stdout/stderr log streams from all ECS tasks.

```bash
# Tail live log streams across all microservices[cite: 34]
aws logs tail /ecs/cloud-design --follow[cite: 34]

# Tail API Gateway microservice logs specifically[cite: 34]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "api-gateway" --follow[cite: 34]

# Tail RabbitMQ message broker logs[cite: 34]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "rabbit-queue" --follow[cite: 34]

# Tail Billing microservice logs[cite: 34]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "billing-app" --follow[cite: 34]

```

---

## 6. Private Host Access & Database Shells (SSM Session Manager)

Securely access private EC2 container hosts and query PostgreSQL databases without exposing public ports.

```bash
# 1. Identify running EC2 host instances[cite: 34, 35]
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text[cite: 34]

# 2. Open an interactive shell on a private EC2 host instance[cite: 34]
aws ssm start-session --target <EC2_INSTANCE_ID>[cite: 34]

# ------------------------------------------------------------------------------
# Executed INSIDE the EC2 Host Terminal Session:
# ------------------------------------------------------------------------------

# List running Docker containers on the host[cite: 35]
sudo docker ps[cite: 35]

# Connect to the Billing PostgreSQL database[cite: 33]
sudo docker exec -it <BILLING_DB_CONTAINER_ID> psql -U billing_user -d billing_db[cite: 33]

# Connect to the Inventory PostgreSQL database[cite: 33]
sudo docker exec -it <INVENTORY_DB_CONTAINER_ID> psql -U inventory_user -d inventory_db[cite: 33]

# Useful psql queries:
# \dt                      --> List tables
# SELECT * FROM movies;    --> Query records
# \q                       --> Exit psql

```

---

## 7. Audit Demonstration & Resilience Procedures

Perform the official validation suite required by the project auditor.

### Step 1: Unauthenticated Endpoint Test (Expect `401 Unauthorized`)

```bash
# Request sent without Bearer token must be rejected at API Gateway edge[cite: 33, 35]
curl -i https://<API_GATEWAY_URL>/movies[cite: 35]

```

### Step 2: Authenticated CRUD Operations

```bash
# Create a new record (POST)[cite: 35]
curl -i -X POST https://<API_GATEWAY_URL>/movies \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Interstellar", "director": "Christopher Nolan"}'[cite: 35]

# Retrieve records (GET)[cite: 35]
curl -i -H "Authorization: Bearer <JWT_TOKEN>" https://<API_GATEWAY_URL>/movies[cite: 35]

```

### Step 3: Message Queue Resilience Test (Billing Outage)

```bash
# 1. Stop the downstream billing service[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 0[cite: 35]

# 2. Send a billing request (Enqueued into RabbitMQ without failing at edge)[cite: 33, 35]
curl -i -X POST https://<API_GATEWAY_URL>/billing \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "usr_77", "amount": 89.99}'[cite: 35]

# 3. Restart the billing consumer service[cite: 35]
aws ecs update-service \
  --cluster cloud-design-cluster \
  --service cloud-design-billing-app \
  --desired-count 1[cite: 35]

# 4. Stream consumer logs to verify automatic consumption of queued messages[cite: 34, 35]
aws logs tail /ecs/cloud-design --log-stream-name-prefix "billing-app" --follow[cite: 34, 35]

```

---

## 8. Helper Script: Service-to-Host Mapping

Run this one-liner to map every ECS microservice directly to its hosting EC2 instance ID:

```bash
for SERVICE in cloud-design-api-gateway-app cloud-design-inventory-app cloud-design-inventory-db cloud-design-billing-app cloud-design-billing-db cloud-design-rabbit-queue; do
  TASK_ARN=$(aws ecs list-tasks --cluster cloud-design-cluster --service-name $SERVICE --query "taskArns[0]" --output text 2>/dev/null)
  if [ "$TASK_ARN" != "None" ] && [ -n "$TASK_ARN" ]; then
    CI_ARN=$(aws ecs describe-tasks --cluster cloud-design-cluster --tasks $TASK_ARN --query "tasks[0].containerInstanceArn" --output text)
    EC2_ID=$(aws ecs describe-container-instances --cluster cloud-design-cluster --container-instances $CI_ARN --query "containerInstances[0].ec2InstanceId" --output text)
    echo "Service: $SERVICE ---> EC2 Host: $EC2_ID"
  else
    echo "Service: $SERVICE ---> (Not Running / Scaled to 0)"
  fi
done[cite: 34, 35]

```