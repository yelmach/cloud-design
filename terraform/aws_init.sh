#!/usr/bin/env bash
set -e

EMAIL="test@cloud.design"
PASSWORD="Test1234*"

echo "=================================================="
echo "1. Fetching Infrastructure Outputs & Details"
echo "=================================================="

# 1. Retrieve User Pool ID & Client ID
USER_POOL_ID=$(terraform output -raw user_pool_id 2>/dev/null || aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?contains(Name, 'cloud-design')].Id | [0]" --output text)
CLIENT_ID=$(terraform output -raw user_pool_client_id 2>/dev/null || aws cognito-idp list-user-pool-clients --user-pool-id "$USER_POOL_ID" --query "UserPoolClients[0].ClientId" --output text)

# 2. Retrieve API Gateway HTTP Invoke URL
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || aws apigatewayv2 get-apis --query "Items[?contains(Name, 'cloud-design')].ApiEndpoint | [0]" --output text)

echo "API Gateway Endpoint : $API_GATEWAY_URL"
echo "Cognito User Pool ID : $USER_POOL_ID"
echo "Cognito Client ID    : $CLIENT_ID"
echo ""

echo "=================================================="
echo "2. Registering & Confirming User ($EMAIL)"
echo "=================================================="

# Register user in Cognito
aws cognito-idp sign-up \
  --client-id "$CLIENT_ID" \
  --username "$EMAIL" \
  --password "$PASSWORD" \
  --user-attributes Name="email",Value="$EMAIL" > /dev/null 2>&1 || echo "Notice: User may already exist, continuing to authentication..."

# Confirm sign-up (bypasses email confirmation code check)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id "$USER_POOL_ID" \
  --username "$EMAIL" > /dev/null 2>&1 || true

echo "User registered and confirmed successfully."
echo ""

echo "=================================================="
echo "3. Authenticating & Generating JWT Tokens"
echo "=================================================="

# Sign in to receive JWT tokens
AUTH_OUTPUT=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$CLIENT_ID" \
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$PASSWORD" \
  --output json)

# Extract tokens using Python (works out of the box without extra dependencies)
ID_TOKEN=$(python3 -c "import sys, json; print(json.load(sys.stdin).get('AuthenticationResult', {}).get('IdToken', ''))" <<< "$AUTH_OUTPUT")
ACCESS_TOKEN=$(python3 -c "import sys, json; print(json.load(sys.stdin).get('AuthenticationResult', {}).get('AccessToken', ''))" <<< "$AUTH_OUTPUT")

echo ""
echo "=================================================="
echo " SUMMARY & RESULTS"
echo "=================================================="
echo "API Gateway Endpoint : $API_GATEWAY_URL"
echo "Cognito User Pool ID : $USER_POOL_ID"
echo "Cognito Client ID    : $CLIENT_ID"
echo "--------------------------------------------------"
echo "JWT ID TOKEN (Pass this to API Gateway):"
echo "$ID_TOKEN"
echo "--------------------------------------------------"
echo "JWT ACCESS TOKEN:"
echo "$ACCESS_TOKEN"
echo "=================================================="