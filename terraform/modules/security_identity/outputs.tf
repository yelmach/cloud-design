output "ecs_execution_role_arn" {
  description = "ARN of the IAM role for ECS task execution (Agent permissions)"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the IAM role for the ECS container runtime"
  value       = aws_iam_role.ecs_task_role.arn
}