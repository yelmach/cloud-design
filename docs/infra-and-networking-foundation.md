# Infrastructure and Networking Foundation

This document explains the infrastructure foundation built for this project. It is written as a learning guide: it describes what each AWS and Terraform component is, why it is useful, and how it is used in this repository.

## What has been built

The current foundation contains:

- An Amazon S3 remote backend for Terraform state.
- A custom Amazon VPC.
- Two public subnets and two private subnets spread across two Availability Zones.
- An Internet Gateway for public internet access.
- Public and private route tables.
- A cost-optimised EC2 NAT instance using the `fck-nat` AMI.
- A security group for the NAT instance.

The application services, databases, load balancer, monitoring, and authentication components will be added on top of this foundation later.

## Terraform and remote state

### What is Terraform state?

Terraform creates infrastructure from `.tf` files, but it also needs a record of what it has created. This record is called the **Terraform state** and is normally stored in a file named `terraform.tfstate`.

The state maps Terraform resource names to the real AWS resources. For example, it stores the ID of the VPC created by `aws_vpc.main`. Terraform uses this information to compare the desired configuration with what already exists, then decide whether it should create, update, or delete a resource.

State can contain sensitive information, such as resource identifiers, network information, and later possibly database connection details. It must be protected and should never be committed to Git.

### What is remote Terraform state?

By default, Terraform keeps the state file on the computer where Terraform runs. This is called **local state**. Local state is inconvenient and risky when more than one person or CI pipeline works on the infrastructure: each machine can have a different copy, and a lost laptop can mean lost infrastructure records.

**Remote state** stores the same file in a shared remote location. This project uses an Amazon S3 bucket named `cloud-design-remote-state`, with the state object stored under `infra/terraform.tfstate`.

Benefits of remote state:

- One shared source of truth for the infrastructure.
- State persists even if the local machine is replaced.
- The S3 backend can encrypt the state at rest.
- State locking stops two Terraform operations from modifying the same infrastructure at the same time.

### How this project configures it

The backend configuration is in `terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "cloud-design-remote-state"
    key          = "infra/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
```

- `bucket` is the S3 bucket used to store the state.
- `key` is the path and filename of the state object inside that bucket.
- `encrypt = true` encrypts the state object at rest.
- `use_lockfile = true` enables S3-native locking. During `terraform plan` or `terraform apply`, Terraform creates a temporary lock object. Another Terraform operation cannot continue until that lock is released. This prevents state corruption caused by simultaneous changes.

The S3 bucket must exist before Terraform can use it as its backend. This is often called **bootstrapping**: create the state bucket once, then configure the rest of the infrastructure to use it. The current Terraform code references the bucket but does not create it, which is appropriate because Terraform cannot use a backend bucket until it already exists.

For a safer production-quality backend, the bucket should also have versioning, Block Public Access, least-privilege IAM access, and a lifecycle policy for old state versions. HashiCorp recommends S3 bucket versioning because it allows recovery from accidental state deletion or overwrite. [Terraform S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3)

## Virtual Private Cloud (VPC)

### What is a VPC?

An **Amazon Virtual Private Cloud (VPC)** is a private virtual network inside AWS. It gives you control over your IP address range, subnets, routing, and network security.

Think of a VPC as the private network of a company office:

- The VPC is the whole office network.
- Subnets are separate rooms or departments.
- Route tables are the directions that tell traffic where to go.
- The Internet Gateway is the building's connection to the outside world.
- Security groups are the access rules at each resource.

This project creates one VPC named `cloud-design-vpc` with the CIDR block `10.0.0.0/16`.

### What is a CIDR block?

A **CIDR block** defines a range of IP addresses. `10.0.0.0/16` covers addresses from `10.0.0.0` to `10.0.255.255`, giving the VPC 65,536 addresses. The `10.x.x.x` range is a private IPv4 address range, so it is suitable for internal infrastructure.

The VPC enables DNS support and DNS hostnames. This lets resources resolve domain names and receive DNS names where applicable, which is useful for future services such as load balancers and databases.

## Subnets and Availability Zones

### What is a subnet?

A **subnet** is a smaller network inside a VPC. Every subnet belongs to one Availability Zone and has its own CIDR block. Dividing the VPC into subnets lets us separate public-facing resources from internal resources.

This project uses four `/24` subnets:

| Subnet type | CIDR blocks | Purpose |
|---|---|---|
| Public subnets | `10.0.10.0/24`, `10.0.11.0/24` | Host resources that need a route to the internet, such as the NAT instance and a future load balancer. |
| Private subnets | `10.0.20.0/24`, `10.0.21.0/24` | Host internal resources, such as future application tasks and databases. |

Each `/24` subnet has 256 addresses. AWS reserves five addresses in each subnet, leaving 251 addresses that can be assigned to resources.

### What is an Availability Zone?

An **Availability Zone (AZ)** is an isolated group of one or more data centres within an AWS location. AZs have independent power, cooling, and networking, while still being connected by low-latency links.

The public and private subnet lists are distributed across two AZs. This is important because future services can run in more than one AZ. If one AZ fails, a correctly designed multi-AZ application can continue operating from the other AZ.

The current network is ready for multi-AZ workloads, but the NAT instance itself is only in one public subnet. Its availability limitation is explained in the NAT section below.

### Public versus private subnets

A subnet is considered **public** when its route table has a route to an Internet Gateway. In this project, public subnets also use `map_public_ip_on_launch = true`, so an EC2 instance launched there automatically receives a public IPv4 address.

A subnet is considered **private** when it has no direct route to an Internet Gateway and its resources do not receive public IP addresses. Private resources can still access the internet for updates or package downloads by using NAT, but the internet cannot start a new connection directly to them.

## Internet Gateway (IGW)

An **Internet Gateway**, or **IGW**, is an AWS-managed gateway attached to a VPC. It provides a path between the VPC and the public internet.

This project creates `cloud-design-igw` and attaches it to `cloud-design-vpc`. An IGW alone does not make resources public: the resource also needs a public IP address and a route table that sends traffic to the IGW.

The IGW is used by the NAT instance in the public subnet. Later, it will also allow a public load balancer to receive requests from users.

## Route tables

### What is a route table?

A **route table** contains rules that decide where network traffic should go. Each subnet is associated with a route table. A route has two main parts:

- **Destination**: the IP range the traffic is trying to reach.
- **Target**: the component that should receive that traffic next.

`0.0.0.0/0` is the default IPv4 route. It means “all IPv4 destinations that do not match a more specific route.”

### Public route table

The public route table is named `cloud-design-public-rt`. It sends `0.0.0.0/0` to the Internet Gateway. Both public subnets are associated with it.

This means resources in public subnets can communicate with the internet when they have a public IPv4 address and their security rules permit the traffic.

### Private route table

The private route table is named `cloud-design-private-rt`. It sends `0.0.0.0/0` to the primary network interface of the NAT instance. Both private subnets are associated with it.

This means private resources send outbound internet traffic to the NAT instance instead of directly to the Internet Gateway. The NAT instance then forwards it through the public subnet and IGW.

## Security group

### What is a security group?

An AWS **security group** is a stateful virtual firewall attached to a resource's network interface. It controls allowed inbound and outbound traffic.

- **Ingress rules** control traffic entering the resource.
- **Egress rules** control traffic leaving the resource.
- **Stateful** means that when an allowed connection is established, return traffic is automatically allowed. You do not have to create an extra inbound rule for a response to permitted outbound traffic.

This project creates `nat-instance-sg` for the NAT instance.

| Direction | Rule in this project | Why |
|---|---|---|
| Ingress | All protocols and ports from `10.0.0.0/16` | Allows resources inside this VPC to send traffic to the NAT instance. |
| Egress | All protocols and ports to `0.0.0.0/0` | Allows the NAT instance to forward private-subnet traffic to the internet. |

The ingress rule is safe from direct internet access because its source is the VPC CIDR, not `0.0.0.0/0`. For a more restrictive future design, it could allow only the private subnet CIDR blocks instead of the entire VPC.

## NAT instance

### What is NAT?

**NAT** means Network Address Translation. A NAT device allows resources with private IP addresses to start outbound connections to the internet without giving them public IP addresses. It translates the private source address to its own public address, then translates reply traffic back to the original private resource.

This is useful for private applications that need to download updates, pull container images, or call external APIs, while remaining unreachable from unsolicited connections from the internet.

### How it is implemented here

Instead of an AWS-managed NAT Gateway, this project launches an EC2 NAT instance named `cloud-design-nat-instance`:

- It uses the `fck-nat` Amazon Linux 2023 AMI, selected dynamically from the latest compatible x86_64 image.
- It uses a `t3.micro` instance type to keep the learning environment inexpensive.
- It runs in the first public subnet, where it receives a public IPv4 address.
- It uses `nat-instance-sg`.
- `source_dest_check = false` is set. EC2 normally checks that packets are sent from or to the instance itself. A NAT instance must forward packets for other machines, so this check must be disabled.

The outbound traffic path is:

```text
Private workload
  -> private route table
  -> NAT instance
  -> public route table
  -> Internet Gateway
  -> Internet
```

### NAT instance trade-offs

The NAT instance is a good low-cost learning choice, but it has trade-offs:

- It is a single point of failure. If it fails, private resources lose internet egress.
- It is located in one AZ. An outage affecting that AZ can also remove egress for private resources in the other AZ.
- Its throughput and availability are limited by the selected EC2 instance type.
- You are responsible for maintaining the instance and its AMI.

A more resilient production architecture commonly uses one NAT Gateway or NAT instance per AZ, with separate private route tables. That costs more but avoids routing traffic across AZs and removes the single-NAT availability risk.

## Estimated monthly cost

The figures below are approximate on-demand costs for a NAT instance running continuously for 730 hours in one month. AWS pricing varies by location, account type, credits, Free Tier eligibility, and data usage; check the AWS Pricing Calculator before deploying.

| Component | Estimated monthly cost | Explanation |
|---|---:|---|
| VPC, subnets, route tables, route associations, security group, and Internet Gateway | $0.00 | These base networking components do not have an hourly charge. |
| `t3.micro` NAT instance | about $8–$10 | The main fixed compute cost. Exact price depends on the selected AWS location. |
| One public IPv4 address | about $3.65 | Calculated as $0.005 per hour × 730 hours. AWS charges for public IPv4 addresses. [AWS public IPv4 pricing guidance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-instance-addressing.html) |
| NAT instance EBS root volume | about $0.60–$1.00 | Depends on the AMI's actual root-volume size and type. |
| S3 Terraform state | less than $0.01 in normal learning use | State is small; storage, requests, and retained versions determine the actual amount. [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/) |
| Data transfer | usage-dependent | Internet egress and traffic between AZs can add charges, so they are not included in the fixed estimate. |

**Estimated fixed total: about $12–$15 per month**, before data transfer, taxes, or any account credits.

The NAT instance is the resource to watch most closely. When the lab is not in use, destroying the Terraform-managed resources stops its compute and public-IP charges. The separately bootstrapped S3 state bucket is not destroyed by this Terraform configuration, so review it separately when cleaning up.

## Useful Terraform commands

Run these commands from the repository root:

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
terraform -chdir=terraform output
```

Use `terraform plan` to preview changes before creating or changing infrastructure. Use `terraform destroy` only when you intentionally want to remove the resources managed by this Terraform state.
