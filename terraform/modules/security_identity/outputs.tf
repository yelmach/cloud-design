# IAM Outputs
output "ecs_execution_role_arn" {
  description = "ARN for ECS Task Execution Role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN for ECS Application Task Role"
  value       = aws_iam_role.ecs_task_role.arn
}

# Cognito Outputs
output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main_user_pool.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main_user_pool.arn
}

output "user_pool_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.app_client.id
}

output "cognito_issuer_url" {
  description = "Issuer URL required for API Gateway JWT Authorizer"
  value       = "https://${aws_cognito_user_pool.main_user_pool.endpoint}"
}

output "ssm_billing_db_password_arn" {
  description = "SSM Parameter ARN for Billing DB Password"
  value       = aws_ssm_parameter.billing_db_password.arn
}
output "ssm_inventory_db_password_arn" {
  description = "SSM Parameter ARN for Inventory DB Password"
  value       = aws_ssm_parameter.inventory_db_password.arn
}
output "ssm_rabbitmq_password_arn" {
  description = "SSM Parameter ARN for RabbitMQ URL"
  value       = aws_ssm_parameter.rabbitmq_password.arn
}


output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main_alb.arn
}

output "alb_dns_name" {
  description = "DNS address of the ALB for internal routing"
  value       = aws_lb.main_alb.dns_name
}

output "alb_target_group_arn" {
  description = "Target Group ARN for ECS tasks to attach to"
  value       = aws_lb_target_group.app_tg.arn
}

output "alb_listener_arn" {
  description = "ARN of the HTTP listener required by API Gateway VPC Link integration"
  value       = aws_lb_listener.http_listener.arn
}