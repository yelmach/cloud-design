# Implemented network infrastructure and cost

## Source of truth

This document describes the Terraform resources **currently declared** in
`modules/network/main.tf`, with root defaults from `variables.tf`. The root
configuration calls only `module "network"`; the ALB, ECS, ECR, RDS, and
security modules are empty and are not deployed by this configuration.

| Setting | Exact configured value |
| --- | --- |
| AWS Region | `eu-west-3` — Europe (Paris) |
| VPC CIDR | `10.0.0.0/16` |
| Availability Zones | One: `eu-west-3a` |
| Public subnet | `10.0.0.0/24`, public-IP mapping enabled |
| Private app subnet | `10.0.10.0/24` |
| Private DB subnet | `10.0.20.0/24` |
| NAT AMI | Latest matching `fck-nat-al2023-*`, x86_64, owner `568608671756` |
| NAT instance | `t3.micro` (not `t3.nano`) |
| NAT public address | **None declared** — no Elastic IP or public IPv4 association resource |

## Architecture declared in Terraform

```mermaid
flowchart LR
    Internet((Internet))
    IGW[Internet Gateway]

    subgraph VPC[VPC 10.0.0.0/16 — eu-west-3a]
        subgraph Public[Public subnet 10.0.0.0/24]
            ENI[NAT ENI\nprivate IPv4 only]
            NAT[fck-nat EC2\nt3.micro]
            SG[NAT security group]
            SG --> NAT --> ENI
        end

        subgraph App[Private app subnet 10.0.10.0/24]
            APP[App workloads]
        end

        subgraph DB[Private DB subnet 10.0.20.0/24]
            DB[DB workloads]
        end
    end

    PublicRT[Public route table\n0.0.0.0/0 → IGW] --> IGW --> Internet
    APP -->|0.0.0.0/0 → NAT ENI| ENI
    DB -->|0.0.0.0/0 → NAT ENI| ENI
```

### Resources and routing

- One VPC has DNS support and DNS hostnames enabled.
- Three subnets are created in `eu-west-3a`: one public, one private-app, and
  one private-DB. The public subnet has `map_public_ip_on_launch = true`.
- One Internet Gateway is attached to the VPC. The public route table sends
  `0.0.0.0/0` to that gateway and is associated with the public subnet.
- One fck-nat AMI is selected dynamically using `most_recent = true`. Its
  actual AMI ID and root-volume mapping may therefore change between plans.
- One security group allows all protocols and ports from `10.0.0.0/16` and
  allows all outbound IPv4 traffic. There are no public ingress rules.
- One ENI is created in the public subnet with the NAT security group and
  `source_dest_check = false`. That ENI is attached as device 0 of one
  `t3.micro` instance.
- One private route table sends `0.0.0.0/0` to the NAT ENI. **Both** the
  private-app and private-DB subnets are associated with this same table.

No custom network ACLs, VPC Flow Logs, VPC endpoints, IPv6 ranges, Elastic
IP, NAT Gateway, load balancer, or application/database resources are
declared in the active configuration.

## Important connectivity result

The NAT design is incomplete as currently written. The NAT instance is
launched with an **existing ENI** as its primary interface. AWS documents
that when an existing ENI is specified as device index 0, auto-assignment of
a public IPv4 address cannot be used; the public address is determined by
that ENI instead. This ENI has no Elastic IP or public IPv4 association.
Consequently, the NAT instance has only a private address and cannot reach
the Internet Gateway for internet egress. The two private default routes
therefore do not currently provide working outbound internet access.

This is not changed by the public subnet's `map_public_ip_on_launch` setting,
because Terraform creates the ENI before attaching it to the instance. AWS
requires a NAT instance to use a public IP address or an Elastic IP address;
see [AWS's NAT comparison](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-comparison.html)
and [primary ENI public-IPv4 behavior](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/working-with-ip-addresses.html).

Also, the database subnet is **not internet-isolated by routing**: it has the
same `0.0.0.0/0 → NAT ENI` route as the application subnet. Once the NAT
instance receives a public address, database resources would be able to make
outbound internet connections. There is no database security group in this
configuration to further restrict that traffic.

## Intended packet path after adding a public address

If an Elastic IP is associated with the NAT ENI, the expected path is:

1. A workload in either private subnet sends non-local IPv4 traffic to its
   shared private route table.
2. The route table forwards it to the NAT ENI.
3. fck-nat translates the source to its public address.
4. The public subnet route table forwards the packet through the Internet
   Gateway.
5. Return traffic reaches the public address, is translated by fck-nat, and
   is delivered to the originating private address.

The NAT security group only permits new inbound connections sourced from the
VPC CIDR. Security groups are stateful, so response traffic for a permitted
outbound connection is allowed.

## Monthly cost calculation

This estimate is for a continuously running deployment, using **730
hours/month**, On-Demand Linux pricing, and USD. It is the cost of resources
declared by the active Terraform configuration only; it does not price the
future services listed in `README.md`.

| Component | Calculation | Monthly estimate |
| --- | --- | ---: |
| VPC, subnets, route tables, Internet Gateway, security group, ENI | No separate hourly price | $0.00 |
| fck-nat compute | `t3.micro` × $0.0118/hour × 730 hours | **$8.61** |
| Public IPv4 / Elastic IP | No public address resource exists | **$0.00** |
| NAT Gateway hourly or per-GB processing | No `aws_nat_gateway` exists | **$0.00** |
| **Known fixed total** | Excludes the AMI root volume and usage charges | **$8.61/month** |

The `t3.micro` estimate uses the Paris-region Linux On-Demand rate of
approximately $0.0118/hour, calculated as `$0.0118 × 730 = $8.614`, rounded
to **$8.61**. Confirm the current rate immediately before deployment in the
[AWS Pricing Calculator](https://calculator.aws/), because rates can change.
AWS charges $0.005 per in-use public IPv4 address per hour; the current cost
is zero only because the configuration does not allocate or associate one.
See [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

### Costs that cannot be exact from this Terraform source

- **Root EBS volume:** The AMI is selected with `most_recent = true` and no
  `root_block_device` is specified. Its snapshot/volume size is not fixed in
  the repository, so the EBS monthly cost cannot be derived exactly. It will
  be added to the EC2 bill when the instance is created.
- **T3 Unlimited CPU credits:** If the instance runs in Unlimited mode and
  exceeds its earned CPU credits, surplus-credit charges depend on measured
  CPU usage. That usage is not knowable from Terraform.
- **Data transfer:** There is currently no functional internet egress because
  there is no public address. After adding an EIP, internet egress and any
  cross-AZ traffic will be usage-based. The present one-AZ default has no
  cross-AZ NAT path.
- **Future resources:** EBS backups, CloudWatch, S3 backend storage,
  DynamoDB state locking, ECS, RDS, ALB, API Gateway, Cognito, and GitHub
  registry costs are outside this active network module and must be costed
  separately when they are added.

## Cost justification and trade-offs

The single `t3.micro` fck-nat instance keeps the known compute baseline at
about $8.61/month and avoids the separate hourly and per-GB processing fees
of a managed NAT Gateway. AWS confirms that managed NAT Gateways are billed
for both availability time and data processed in its [NAT Gateway pricing
[guide](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-pricing.html).

That saving comes with one Availability Zone, one instance, limited
throughput, patching responsibility, and a single point of failure. AWS
recommends managed NAT Gateways when greater availability, bandwidth, and
lower operational burden are required. For a production design, use a NAT
solution per active AZ and consider VPC endpoints for AWS services such as
S3 and ECR to reduce NAT traffic.
