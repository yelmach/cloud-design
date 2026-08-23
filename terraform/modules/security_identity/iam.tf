data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

}

# Attach Standard AWS Managed Policy for ECS Execution (Logs + Image pulls)
resource "aws_iam_role_policy_attachment" "ecs_execution_standard_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom Policy: Grant ECS permission to read application secrets from SSM
data "aws_iam_policy_document" "ecs_ssm_read_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParametersByPath"
    ]

    # Restrict access strictly to your app's namespace (Least Privilege)
    resources = ["arn:aws:ssm:*:*:parameter/app/*"]
  }
}
#Allows ECS agent to retrieve parameters from SSM Parameter Store
resource "aws_iam_policy" "ecs_ssm_read_policy" {
  name   = "${var.project_name}-ecs-ssm-read-policy"
  policy = data.aws_iam_policy_document.ecs_ssm_read_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_ssm_read_policy.arn
}


