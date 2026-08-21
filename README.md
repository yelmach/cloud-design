# cloud-design

1. Network & Infrastructure Foundation
Amazon VPC (Virtual Private Cloud)
Security Groups (SGs)
NAT Instance (EC2) (fknat)

2. Compute & Orchestration
Amazon ECS (Elastic Container Service)
Amazon EC2 (t3.small)
Docker Hub

3. Databases & Messaging
Amazon RDS (db.t3.micro / db.t4g.micro)
RabbitMQ Container (directly)

4. Traffic Routing, Security & Identity
AWS API Gateway
Application Load Balancer (ALB)
Amazon Cognito
AWS IAM (Identity and Access Management)
AWS Certificate Manager (ACM)
AWS SSM Parameter Store

5. Observability & Infrastructure as Code (IaC)
Terraform
Amazon S3 + DynamoDB (remote backend for Terraform)
Amazon CloudWatch



------------------------------------------------------------------------------------------------------------------
4. What Goes Inside Each Phase 4 Module
Module A: modules/security_identity/

iam.tf: Creates ECS task execution roles, CloudWatch logging roles, and attaches read-only SSM policies. done


cognito.tf: Configures Cognito User Pool and App Client for issuing JWT auth tokens. done


ssm.tf: Sets up /app/db/host, /app/db/password, and /app/rabbitmq/url placeholders. 

outputs.tf:

Terraform
output "ecs_execution_role_arn" { value = aws_iam_role.ecs_execution_role.arn }
output "user_pool_id"          { value = aws_cognito_user_pool.user_pool.id }
output "user_pool_client_id"   { value = aws_cognito_user_pool_client.client.id }
output "user_pool_endpoint"    { value = aws_cognito_user_pool.user_pool.endpoint }
Module B: modules/traffic_routing/

alb.tf: Defines the Application Load Balancer inside private/public subnets, HTTP listener, and Target Group.


apigateway.tf: Configures HTTP API Gateway, HTTP_PROXY integration using aws_apigatewayv2_vpc_link, and JWT Cognito Authorizer.

outputs.tf:

Terraform
output "target_group_arn"     { value = aws_lb_target_group.app_tg.arn }
output "api_gateway_endpoint" { value = aws_apigatewayv2_stage.default_stage.invoke_url }