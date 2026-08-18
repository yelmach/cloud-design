# Build It Yourself: Step-by-Step From an Empty Repo

No pre-written files. You type everything. Each step tells you *what* to
create and *why* it exists, plus the AWS/Terraform concepts you need — but
you write the actual HCL. Look up the exact resource syntax in the
[Terraform AWS provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
as you go — reading provider docs is itself a core Terraform skill.

Work through this in order. Don't skip ahead — each step depends on the last.

---

## Step 0 — Folder structure

Create this layout first, empty files are fine to start:

```
your-repo/
├── bootstrap/
│   └── main.tf
├── backend.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── modules/
    ├── network/
    ├── security/
    ├── ecr/
    ├── rds/
    ├── alb/
    └── ecs/
```

Each module folder will get its own `main.tf`, `variables.tf`, `outputs.tf`.
Also add a `.gitignore`:

```
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfvars
```

---

## Step 1 — `bootstrap/main.tf`: remote state storage

**Concept:** Terraform needs somewhere to store its state file (a JSON record
of what it created). You want that in S3, not on your laptop, so it's shared
and safe. But you can't store state in a bucket that doesn't exist yet — so
this one small config runs *first*, with local state, purely to create:

- One `aws_s3_bucket` (versioning enabled, encryption enabled, public access
  blocked)
- One `aws_dynamodb_table` for state locking (prevents two people/you-in-two-
  terminals from applying at the same time and corrupting state)

Write it, then:
```bash
cd bootstrap && terraform init && terraform apply
```

---

## Step 2 — `provider.tf` and `backend.tf` (root)

**Concept:** `provider.tf` tells Terraform "talk to AWS, this region." The
`backend "s3"` block in `backend.tf` tells Terraform "store state in the
bucket from Step 1, lock it with that DynamoDB table."

This part is pure boilerplate syntax, so here's the shape (fill in your own
values):

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "YOUR-BUCKET-FROM-STEP-1"
    key            = "microservices/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "YOUR-LOCK-TABLE-FROM-STEP-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
```

---

## Step 3 — `variables.tf` (root)

**Concept:** every value you might want to change per-environment (region,
CIDR blocks, instance sizes, passwords) becomes a `variable` block instead
of a hardcoded value. Think through what you'll need across the *whole*
project before writing modules — you'll add more as you go, but get the
obvious ones now:

- `aws_region`, `project_name`, `environment`
- `vpc_cidr`, list of `azs`
- subnet CIDR lists — you need **three tiers**: public, private-app,
  private-db (think about *why* three tiers, not two, given the requirement
  that databases must only be reachable from the VPC)
- `db_username`, `db_password` (mark `sensitive = true` — look up what that
  does and why it matters)
- ECS sizing: instance type, min/max/desired count

Don't write default passwords into this file. You'll pass `db_password` via
`TF_VAR_db_password` environment variable instead — figure out why that
matters before moving on.

---

## Step 4 — `modules/network`

**Concept:** this is your foundation — nothing else can be created without
it. Build, in order:

1. `aws_vpc`
2. Public subnets (one per AZ) — these will hold the ALB and NAT Gateway
3. Private "app" subnets (one per AZ) — ECS instances live here
4. Private "db" subnets (one per AZ) — RDS lives here, one layer more isolated
5. `aws_internet_gateway` — gives the VPC a path to/from the internet
6. `aws_nat_gateway` (+ `aws_eip` for it) — lets things in *private* subnets
   reach the internet (e.g. to pull Docker images) without being reachable
   *from* the internet. Ask yourself: why does ECS need outbound internet
   access at all if it's not public-facing? (Hint: pulling from ECR/ghcr,
   hitting AWS APIs.)
7. Route tables: one for public subnets (routes `0.0.0.0/0` → IGW), one for
   private subnets (routes `0.0.0.0/0` → NAT Gateway)
8. `aws_route_table_association` for each subnet

**Decision to make yourself:** one NAT Gateway (cheaper, single point of
failure) or one per AZ (full HA, ~2x cost)? Either is defensible for a
class project — just know the tradeoff.

Module outputs you'll need later: vpc_id, and each subnet-id list.

---

## Step 5 — `modules/security`

**Concept:** four security groups, each only allowing traffic from the layer
above it — this is what actually enforces "databases only reachable from
inside the VPC."

Work out the chain yourself:
- **ALB SG**: what's the only thing that should reach it, and on what port?
- **ECS SG**: what should be allowed to reach *it*? (Hint: the ALB SG, by
  reference — not a CIDR block. Also think about whether services need to
  talk to each other.)
- **RDS SG**: allow port 5432 from... which SG? (Not the ALB — the databases
  should never be reachable from the ALB directly.)
- **RabbitMQ SG**: allow 5672 (and optionally 15672 for the management UI)
  from which SG?

Referencing another security group as the source (instead of a CIDR block)
is the key Terraform/AWS pattern here — look up `security_groups` inside an
`ingress` block.

---

## Step 6 — `modules/ecr`

**Concept:** one ECR repository per image you'll push: `inventory-app`,
`billing-app`, `api-gateway-app` (RabbitMQ uses the public Docker Hub image,
so it doesn't need its own ECR repo).

Use `for_each` over a list of repo names instead of copy-pasting the
resource block three times — this is a core Terraform pattern worth
practicing now, since you'll use it constantly.

Bonus: add `image_scanning_configuration { scan_on_push = true }` — this is
your vulnerability scanning requirement, basically free.

At this point you can actually apply what exists so far:
```bash
terraform init
terraform apply -target=module.network -target=module.security -target=module.ecr
```
Then go build/tag/push your three app images to the repo URLs you get back.

---

## Step 7 — `modules/rds`

**Concept:** two `aws_db_instance` resources (postgres), `inventory-db` and
`billing-db`, both:
- In an `aws_db_subnet_group` built from your **private-db** subnet ids
- Attached to the RDS security group from Step 5
- `publicly_accessible = false`
- `storage_encrypted = true`

Think about `multi_az` — what does it cost you, what does it buy you? Decide
and be ready to explain the tradeoff.

---

## Step 8 — `modules/alb`

**Concept:**
- `aws_lb` (application type) in the **public** subnets, using the ALB SG
- An `aws_acm_certificate` (DNS validation — needs a domain you control)
- An HTTPS listener (443) forwarding to a target group pointed at
  `api-gateway-app` (port 3000)
- An HTTP (80) listener that just redirects to HTTPS — look up the
  `redirect` action type on `aws_lb_listener`

---

## Step 9 — `modules/ecs`

This is the biggest module — build it in this sub-order:

1. **IAM first**: an EC2 instance role (so ECS agent can register hosts), a
   task execution role (so ECS can pull images and write logs — attach the
   AWS-managed `AmazonECSTaskExecutionRolePolicy`), and a task role (what the
   app itself can call — start minimal).
2. **Cluster**: `aws_ecs_cluster`, turn on Container Insights.
3. **Capacity**: a launch template using the ECS-optimized AMI (look up the
   SSM public parameter for it — don't hardcode an AMI ID), an
   `aws_autoscaling_group` in the private-app subnets, and an
   `aws_ecs_capacity_provider` tying the ASG to the cluster.
4. **CloudWatch log groups**: one per service.
5. **Task definitions + services**, one set per container:
   `inventory-app`, `billing-app`, `rabbit-queue`, `api-gateway-app`. For
   each: what port does it listen on, what env vars/secrets does it need
   (DB host, DB credentials from SSM), which security group and subnets.
6. **Service discovery** for `rabbit-queue` so `billing-app` can find it by
   DNS name — look up `aws_service_discovery_private_dns_namespace` +
   `aws_service_discovery_service`. This needs `network_mode = "awsvpc"` on
   that task, unlike the others — figure out why.
7. **Auto scaling**: `aws_appautoscaling_target` +
   `aws_appautoscaling_policy` (target-tracking on CPU) for at least
   `api-gateway-app`.

Build and apply **one service at a time** (`inventory-app` first, alone) so
you can debug one thing at a time instead of five.

---

## Step 10 — SSM Parameter Store for secrets

**Concept:** `aws_ssm_parameter` (type `SecureString`) for `db_username` and
`db_password`, referenced inside your ECS task definitions' `secrets` block
(not `environment`) — look up the difference and why it matters for
credentials specifically.

---

## Step 11 — Root `main.tf`: wire the modules together

Now write the root `main.tf` that calls every module with `module "x" {
source = "./modules/x" ... }`, passing outputs from earlier modules as
inputs to later ones (e.g. `module.network.vpc_id` into `module.security`).
This is where you'll discover if your module input/output variables don't
line up — that's normal and how you learn to read Terraform's error
messages.

---

## Step 12 — Deploy, break things, tear down

Same practice loop as before:
```bash
terraform plan            # read it, actually read it
terraform apply -target=module.X   # one layer at a time
```
Check the AWS console after each layer. Intentionally break something (stop
a task, tighten a security group) and watch what happens. Then:
```bash
terraform destroy
```
before you walk away, so nothing bills overnight.

---

## When you get stuck

Paste me the **exact error message** plus the resource block that's failing
— I'll help you debug it, not rewrite it for you, so this actually sticks.