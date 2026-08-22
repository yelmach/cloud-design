resource "aws_cloudwatch_dashboard" "platform_insights" {
  dashboard_name = "${var.project_name}-performance-and-health"

  dashboard_body = jsonencode({
    widgets = [
      # Banner Header
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "## Microservices Platform Performance & Health Dashboard\nReal-time operational insights into API Gateway, load balancing health, ECS container utilization, and runtime log streams."
        }
      },

      # 1. API Gateway Request Throughput & Error Rates
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.api_gw.id, { "stat" = "Sum", "label" = "Total Requests" } ],
            [ ".", "4XXError", ".", ".", { "stat" = "Sum", "color" = "#ff7f0e", "label" = "4xx Client Errors" } ],
            [ ".", "5XXError", ".", ".", { "stat" = "Sum", "color" = "#d62728", "label" = "5xx Server Errors" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "API Gateway Traffic & Errors (Application Health)"
          view   = "timeSeries"
        }
      },

      # 2. API Gateway Latency Percentiles (p50 / p95 / p99)
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApiGateway", "Latency", "ApiId", aws_apigatewayv2_api.api_gw.id , { "stat" = "p50", "label" = "p50 Latency (ms)" } ],
            [ "...", { "stat" = "p95", "label" = "p95 Latency (ms)", "color" = "#ff7f0e" } ],
            [ "...", { "stat" = "p99", "label" = "p99 Latency (ms)", "color" = "#d62728" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "API Response Latency (Application Performance)"
          view   = "timeSeries"
          yAxis  = { left = { min = 0 } }
        }
      },

      # 3. ALB Target Health (Healthy vs Unhealthy Hosts)
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.alb_target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { "stat" = "Average", "color" = "#2ca02c", "label" = "Healthy Containers" } ],
            [ ".", "UnHealthyHostCount", ".", ".", ".", ".", { "stat" = "Average", "color" = "#d62728", "label" = "Unhealthy Containers" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "Target Group Host Availability"
          view   = "timeSeries"
        }
      },

      # 4. Cluster Aggregate CPU Utilization
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "CPUUtilization", "ClusterName", "${var.project_name}-cluster", { "stat" = "Average", "label" = "Cluster Avg CPU %" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "ECS Cluster Aggregate CPU Utilization (%)"
          view   = "timeSeries"
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },

      # 5. Cluster Aggregate Memory Utilization
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "MemoryUtilization", "ClusterName", "${var.project_name}-cluster", { "stat" = "Average", "color" = "#9467bd", "label" = "Cluster Avg Memory %" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "ECS Cluster Aggregate Memory Utilization (%)"
          view   = "timeSeries"
          yAxis  = { left = { min = 0, max = 100 } }
        }
      },

      # 6. Per-Microservice CPU Utilization
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-api-gateway-app", "ClusterName", "${var.project_name}-cluster", { "label" = "api-gateway" } ],
            [ "...", "${var.project_name}-inventory-app", ".", ".", { "label" = "inventory-app" } ],
            [ "...", "${var.project_name}-billing-app", ".", ".", { "label" = "billing-app" } ],
            [ "...", "${var.project_name}-rabbit-queue", ".", ".", { "label" = "rabbit-queue" } ],
            [ "...", "${var.project_name}-inventory-db", ".", ".", { "label" = "inventory-db" } ],
            [ "...", "${var.project_name}-billing-db", ".", ".", { "label" = "billing-db" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "Per-Microservice CPU Usage (%)"
          view   = "timeSeries"
        }
      },

      # 7. Per-Microservice Memory Utilization
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ECS", "MemoryUtilization", "ServiceName", "${var.project_name}-api-gateway-app", "ClusterName", "${var.project_name}-cluster", { "label" = "api-gateway" } ],
            [ "...", "${var.project_name}-inventory-app", ".", ".", { "label" = "inventory-app" } ],
            [ "...", "${var.project_name}-billing-app", ".", ".", { "label" = "billing-app" } ],
            [ "...", "${var.project_name}-rabbit-queue", ".", ".", { "label" = "rabbit-queue" } ],
            [ "...", "${var.project_name}-inventory-db", ".", ".", { "label" = "inventory-db" } ],
            [ "...", "${var.project_name}-billing-db", ".", ".", { "label" = "billing-db" } ]
          ]
          period = 60
          region = var.aws_region
          title  = "Per-Microservice Memory Usage (%)"
          view   = "timeSeries"
        }
      },

      # 8. Live Application Error Logs (CloudWatch Logs Insights Widget)
      {
        type   = "log"
        x      = 0
        y      = 20
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '/ecs/${var.project_name}' | fields @timestamp, @logStream, @message | filter @message like /(?i)(error|exception|fail|fatal)/ | sort @timestamp desc | limit 20"
          region = var.aws_region
          title  = "Live Error & Exception Stream across Microservices (CloudWatch Logs Insights)"
          view   = "table"
        }
      }
    ]
  })
}