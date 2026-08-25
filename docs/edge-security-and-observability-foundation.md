# Edge, Security, and Observability Foundation

This document explains the edge and security layer built for this project. It is written as a learning guide: it describes what each AWS and Terraform component is, why it is useful, and how it is used in this repository.

## What has been built

The edge, security, and observability layer contains:

- An internal Application Load Balancer (ALB) that receives traffic from API Gateway and forwards it to the `api-gateway-app` container.
- An AWS API Gateway HTTP API that acts as the public entry point for all client requests.
- A VPC Link that connects API Gateway to the private ALB without exposing the ALB to the internet.
- A Cognito JWT Authorizer that protects all API Gateway routes, rejecting unauthenticated requests automatically.
- An Amazon Cognito User Pool and App Client for managed user authentication.
- A CloudWatch dashboard with eight metric and log widgets providing real-time operational visibility.

---

## Application Load Balancer (ALB)

### What is an Application Load Balancer?

An **Application Load Balancer (ALB)** operates at Layer 7 of the network stack, meaning it understands HTTP and HTTPS traffic. It receives requests on a listener, evaluates routing rules, and forwards traffic to a pool of registered targets, such as container tasks.

This project uses an internal ALB. The word *internal* means it has no public IP address and is only reachable from within the VPC. Clients on the internet cannot reach the ALB directly. All external traffic arrives through API Gateway and is forwarded to the ALB through a private channel called a VPC Link.

### ALB security group

The ALB has a dedicated security group named `cloud-design-alb-sg`:

| Direction | Rule | Purpose |
|---|---|---|
| Inbound | Port `80` from VPC CIDR | Allows the VPC Link network interface to reach the ALB |
| Outbound | All traffic | Allows the ALB to forward requests to target containers |

Because the ALB is internal and accessed only through the VPC Link, the inbound rule restricts access to the VPC address space rather than the internet.

### Target group

The ALB forwards traffic to a **target group** named `cloud-design-tg`. A target group is a list of destinations along with health-check configuration. The ALB only forwards traffic to targets that pass their health check.

Key target group settings:

| Setting | Value | Reason |
|---|---|---|
| `target_type` | `ip` | Required for ECS tasks using `awsvpc` networking; each task registers its own private IP |
| Port | `3000` | The port that `api-gateway-app` listens on |
| Health check path | `/health` | The endpoint the ALB checks to determine if a task is healthy |
| Health check matcher | `200` | Only a 200 response is considered healthy |
| Healthy threshold | 3 | Three consecutive successes required to mark a target healthy |
| Unhealthy threshold | 3 | Three consecutive failures required to mark a target unhealthy |

The `api-gateway-app` Flask application exposes `GET /health` returning `{"status": "ok"}` with HTTP 200. This is what the ALB health check calls every 30 seconds per registered task.

### Listener

The ALB has one listener on **port 80** using HTTP. Its default action forwards all traffic to the `cloud-design-tg` target group. API Gateway sends requests to the ALB through the VPC Link over HTTP; this is safe because the traffic never leaves the private AWS backbone.

---

## AWS API Gateway

### What is API Gateway?

**Amazon API Gateway** is a fully managed service for creating, publishing, and securing HTTP and WebSocket APIs. In this project, API Gateway acts as the **public entry point** for all client requests. It provides:

- A public HTTPS endpoint that clients connect to.
- JWT-based authentication enforced before any request reaches the application.
- Traffic routing to the private VPC network through a VPC Link.

This project uses the **HTTP API** type, which is faster and cheaper than the older REST API type and supports JWT authorizers natively.

### VPC Link

A **VPC Link** is a private channel that allows API Gateway to send traffic directly into a VPC without that traffic ever crossing the public internet. The traffic path is:

```text
Client
  -> API Gateway (public HTTPS endpoint)
  -> VPC Link (private tunnel)
  -> Internal ALB (inside private subnets)
  -> api-gateway-app ECS task
```

The VPC Link is created with `var.alb_security_group_id` as its security group and placed in the private subnets. This lets the VPC Link's network interface reach the ALB listener on port 80.

### Integration

The API Gateway integration connects the HTTP API to the ALB through the VPC Link:

```hcl
resource "aws_apigatewayv2_integration" "alb_integration" {
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.alb_listener_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.vpc_link.id
}
```

- `integration_type = "HTTP_PROXY"` passes the full request to the backend unchanged, including path, headers, and body.
- `integration_uri` is the ARN of the ALB listener. API Gateway uses this to identify the ALB endpoint to forward to.
- `integration_method = "ANY"` means all HTTP methods (GET, POST, PUT, DELETE, etc.) are forwarded.

### Route

One route handles all incoming traffic:

```hcl
resource "aws_apigatewayv2_route" "protected_route" {
  route_key          = "ANY /{proxy+}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}
```

`ANY /{proxy+}` is a catch-all: it matches any HTTP method and any path. The `{proxy+}` segment captures the full path and passes it to the integration. This means `/api/movies`, `/api/billing`, and any future path are all handled by this single route.

Every request matching this route must carry a valid JWT in the `Authorization` header. Requests without one are rejected at the API Gateway layer with `401 Unauthorized` before they ever reach the application containers.

### Stage and deployment

The project uses the built-in `$default` stage with `auto_deploy = true`. This means every configuration change to the API is deployed automatically without a manual release step. The stage produces the public invoke URL that clients use.

---

## Amazon Cognito

### What is Amazon Cognito?

**Amazon Cognito** is a managed user authentication service. It handles user registration, login, password policies, and token issuance without requiring you to build an authentication system from scratch.

This project uses Cognito's **User Pool**, which stores user accounts and issues industry-standard **JSON Web Tokens (JWTs)** after a successful login.

### User Pool

The User Pool is named `cloud-design-user-pool`. Its settings:

| Setting | Value | Reason |
|---|---|---|
| Sign-in attribute | Email | Users log in with their email address, which is unique |
| Minimum password length | 8 characters | Baseline security requirement |
| Uppercase required | Yes | Prevents trivially weak passwords |
| Lowercase required | Yes | Prevents trivially weak passwords |
| Numbers required | Yes | Prevents trivially weak passwords |
| Symbols required | Yes | Prevents trivially weak passwords |
| Temporary password validity | 7 days | Sets how long an admin-created temporary password remains valid |

### App Client

An **App Client** is a configuration inside the User Pool that represents one application allowed to authenticate users. The App Client named `cloud-design-app-client` is configured with:

| Setting | Value | Reason |
|---|---|---|
| `generate_secret` | `false` | Allows public clients such as Postman or a web SPA to authenticate without a client secret |
| `ALLOW_USER_PASSWORD_AUTH` | Enabled | Allows direct username/password login, needed for Postman and CLI-based testing |
| `ALLOW_REFRESH_TOKEN_AUTH` | Enabled | Allows clients to renew an expired access token without asking the user to log in again |
| `ALLOW_USER_SRP_AUTH` | Enabled | Enables the Secure Remote Password protocol, which is the default used by AWS SDKs |

### Authentication flow

When a user authenticates:

1. The client calls Cognito's `InitiateAuth` endpoint with the email and password.
2. Cognito validates the credentials and returns three tokens:
   - **ID Token** — contains the user's identity claims (email, user ID). This is what the API Gateway JWT authorizer validates.
   - **Access Token** — used for authorising calls to Cognito's own management APIs.
   - **Refresh Token** — used to silently obtain new ID and access tokens after they expire.
3. The client includes the ID Token in the `Authorization: Bearer <token>` header on each API request.

### JWT Authorizer

The API Gateway JWT Authorizer is named `cognito-authorizer`. It validates the ID Token on every incoming request before the request is forwarded to the application.

```hcl
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = var.cognito_issuer_url
  }
}
```

- `identity_sources` tells API Gateway where to find the token — in the `Authorization` request header.
- `issuer` is the Cognito User Pool endpoint URL. API Gateway uses this to download Cognito's public signing keys and verify the token's signature.
- `audience` is the App Client ID. API Gateway checks that the token was issued for this specific client, preventing tokens from other applications being accepted.

If the token is missing, expired, or issued for a different audience, API Gateway returns `401 Unauthorized` immediately. The application containers never see unauthenticated requests.

### Creating and confirming a user

Users can be created and confirmed with the AWS CLI:

```bash
# Register the user
aws cognito-idp sign-up \
  --region eu-west-2 \
  --client-id "$CLIENT_ID" \
  --username "$EMAIL" \
  --password "$PASSWORD" \
  --user-attributes Name=email,Value="$EMAIL"

# Confirm the account (bypasses email verification)
aws cognito-idp admin-confirm-sign-up \
  --region eu-west-2 \
  --user-pool-id "$USER_POOL_ID" \
  --username "$EMAIL"
```

The repository also includes `terraform/aws_init.sh`, which automates user registration, confirmation, and JWT retrieval in one script.

---

## CloudWatch dashboard

### What is a CloudWatch dashboard?

A **CloudWatch dashboard** is a customisable monitoring page in the AWS console. It displays metric graphs, alarms, and log query results in a grid layout. Dashboards provide a single view of application health and performance without switching between multiple services.

### Dashboard layout

The project creates the `cloud-design-performance-and-health` dashboard with eight widgets arranged across three rows:

#### Row 1 — API Gateway traffic and latency

| Widget | Metrics | Purpose |
|---|---|---|
| API Gateway Traffic & Errors | `Count`, `4XXError`, `5XXError` summed per minute | Shows total request volume and error rates at a glance |
| API Response Latency | `Latency` at p50, p95, p99 | Reveals tail latency issues that averages would hide |
| Target Group Host Availability | `HealthyHostCount`, `UnHealthyHostCount` | Shows how many containers the ALB considers healthy |

#### Row 2 — ECS cluster utilisation

| Widget | Metrics | Purpose |
|---|---|---|
| Cluster Aggregate CPU | `CPUUtilization` for the cluster | Overall CPU demand across all containers |
| Cluster Aggregate Memory | `MemoryUtilization` for the cluster | Overall memory demand across all containers |

#### Row 3 — Per-service utilisation and live logs

| Widget | Metrics | Purpose |
|---|---|---|
| Per-Microservice CPU | `CPUUtilization` per service name | Identifies which service is driving CPU consumption |
| Per-Microservice Memory | `MemoryUtilization` per service name | Identifies memory growth per service |
| Live Error Stream | CloudWatch Logs Insights query | Shows the 20 most recent log lines matching `error`, `exception`, `fail`, or `fatal` across all services |

### Why latency percentiles matter

The p50 latency is the median — half of all requests complete faster than this value. The p95 latency is experienced by the slowest 5 % of requests. The p99 latency is experienced by the slowest 1 %. Tracking percentiles instead of averages prevents a healthy median from hiding serious performance problems affecting a fraction of users.

### Logs Insights query

The error log widget uses a Logs Insights query:

```
SOURCE '/ecs/cloud-design'
| fields @timestamp, @logStream, @message
| filter @message like /(?i)(error|exception|fail|fatal)/
| sort @timestamp desc
| limit 20
```

This queries all log streams in the `/ecs/cloud-design` group and shows the 20 most recent lines that contain error-related keywords. The `(?i)` flag makes the search case-insensitive, so `Error`, `ERROR`, and `error` all match.

---

## Estimated monthly cost additions

| Component | Estimated monthly cost | Explanation |
|---|---:|---|
| API Gateway HTTP API | usage-dependent | $1.00 per million requests. Low-volume lab usage costs fractions of a cent. [API Gateway pricing](https://aws.amazon.com/api-gateway/pricing/) |
| VPC Link for HTTP API | $0.00 | Unlike REST API VPC Links, VPC Links for HTTP APIs (API Gateway v2) incur no hourly charge. [API Gateway pricing](https://aws.amazon.com/api-gateway/pricing/) |
| Internal ALB | about $16–$20 | Base charge of $0.0225/hour (~$16.43/mo) plus LCU usage. [ALB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) |
| Cognito User Pool | $0.00 | Free for the first 10,000 monthly active users (MAUs). [Cognito pricing](https://aws.amazon.com/cognito/pricing/) |
| CloudWatch dashboard | $0.00 | The first three dashboards with up to 50 metrics are free. [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) |
| CloudWatch Logs Insights | usage-dependent | Charged per GB of data scanned per query. Low-volume lab queries cost fractions of a cent. |

**The internal Application Load Balancer is the main cost driver in this edge layer (~$16–$20/month).** When the lab is not in use, running `terraform destroy` stops all ALB and compute hourly charges.

---

## Useful commands

### Get the public API Gateway URL

```bash
aws apigatewayv2 get-apis \
  --region eu-west-2 \
  --query "Items[?Name=='cloud-design-api-gateway'].ApiEndpoint | [0]" \
  --output text
```

### Get Cognito identifiers

```bash
USER_POOL_ID=$(aws cognito-idp list-user-pools \
  --region eu-west-2 \
  --max-results 60 \
  --query "UserPools[?Name=='cloud-design-user-pool'].Id | [0]" \
  --output text)

CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
  --region eu-west-2 \
  --user-pool-id "$USER_POOL_ID" \
  --query 'UserPoolClients[0].ClientId' \
  --output text)

echo "User Pool : $USER_POOL_ID"
echo "Client ID : $CLIENT_ID"
```

### Obtain a JWT token

```bash
JWT_TOKEN=$(aws cognito-idp initiate-auth \
  --region eu-west-2 \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$CLIENT_ID" \
  --auth-parameters USERNAME="$EMAIL",PASSWORD="$PASSWORD" \
  --query 'AuthenticationResult.IdToken' \
  --output text)
```

### Verify authentication rejection

An unauthenticated request should return `401 Unauthorized`:

```bash
curl -i "$API_GATEWAY_URL/api/movies"
```

### Check ALB target health

```bash
aws elbv2 describe-target-health \
  --region eu-west-2 \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[*].{IP:Target.Id,Port:Target.Port,State:TargetHealth.State}' \
  --output table
```
