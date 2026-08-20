resource "aws_cognito_user_pool" "main_user_pool" {
  name = "${var.project_name}-user-pool"

  # Sign-in Method: Users log in using their Email address
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password Policy (Production Security Baseline)
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
    temporary_password_validity_days = 7
  }

  # Attribute Schema: username is mandatory and immutable once created
  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = false

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  tags = {
    Name        = "${var.project_name}-user-pool"
  }
}

resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.main_user_pool.id

  # Set generate_secret = false for public clients (Web SPAs / Mobile Apps / Postman)
  generate_secret = false

  # Allowed Authentication Flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH", # Required for direct username/password login via Postman/SDK
    "ALLOW_REFRESH_TOKEN_AUTH", # Required to renew expired access tokens
    "ALLOW_USER_SRP_AUTH"       # Secure Remote Password protocol (SDK default)
  ]
}