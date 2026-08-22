# 1. HTTP API Gateway Instance
resource "aws_apigatewayv2_api" "api_gw" {
  name          = "${var.project_name}-api-gateway"
  protocol_type = "HTTP"

  tags = { Name = "${var.project_name}-api-gateway" }
}

# 2. VPC Link (Routes traffic into private subnets / ALB)
resource "aws_apigatewayv2_vpc_link" "vpc_link" {
  name               = "${var.project_name}-vpc-link"
  security_group_ids = [aws_security_group.app_sg.id]
  subnet_ids         = var.private_subnet_ids
}

# 3. Cognito JWT Authorizer
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.api_gw.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = var.cognito_issuer_url
  }
}

# 4. HTTP Proxy Integration pointing to ALB Listener
resource "aws_apigatewayv2_integration" "alb_integration" {
  api_id             = aws_apigatewayv2_api.api_gw.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.alb_listener_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link.id
}

# 5. Protected Route requiring JWT
resource "aws_apigatewayv2_route" "protected_route" {
  api_id             = aws_apigatewayv2_api.api_gw.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# 6. Auto-Deploying Default Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api_gw.id
  name        = "$default"
  auto_deploy = true
}