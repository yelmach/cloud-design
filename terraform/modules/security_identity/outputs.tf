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