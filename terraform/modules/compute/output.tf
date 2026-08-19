output "ecs_cluster_name" {
  description = "Name of the ECS cluster for ECS services and CLI commands"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "capacity_provider_name" {
  description = "Name of the ECS capacity provider backed by the Auto Scaling group"
  value       = aws_ecs_capacity_provider.ecs.name
}

output "ecs_auto_scaling_group_name" {
  description = "Name of the Auto Scaling group that provides ECS container instances"
  value       = aws_autoscaling_group.ecs.name
}

output "ecs_auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling group that provides ECS container instances"
  value       = aws_autoscaling_group.ecs.arn
}

output "ecs_launch_template_id" {
  description = "ID of the launch template used for ECS container instances"
  value       = aws_launch_template.ecs_host.id
}

output "ecs_host_security_group_id" {
  description = "ID of the security group attached to ECS container instances"
  value       = aws_security_group.ecs_sg.id
}

output "ecs_instance_profile_name" {
  description = "Name of the IAM instance profile attached to ECS container instances"
  value       = aws_iam_instance_profile.ecs_instance_profile.name
}
