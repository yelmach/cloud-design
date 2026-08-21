output "ecs_execution_role_arn" {
  description = "ARN of the IAM role for ECS task execution (Agent permissions)"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the IAM role for the ECS container runtime"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ssm_db_host_arn" {
  description = "SSM Parameter ARN for DB Host"
  value       = aws_ssm_parameter.db_host.arn
}

output "ssm_db_password_arn" {
  description = "SSM Parameter ARN for DB Password"
  value       = aws_ssm_parameter.db_password.arn
}

output "ssm_rabbitmq_url_arn" {
  description = "SSM Parameter ARN for RabbitMQ URL"
  value       = aws_ssm_parameter.rabbitmq_url.arn
}