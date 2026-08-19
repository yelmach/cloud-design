# Compute Foundation

This document explains the compute foundation built for this project. It is written as a learning guide: it describes what each AWS and Terraform component is, why it is useful, and how it is used in this repository.

## What has been built

The current compute foundation contains:

- An Amazon ECS cluster.
- An IAM role and instance profile for ECS container instances.
- A security group for the private ECS hosts.
- An ECS-optimised Amazon Linux 2023 AMI obtained from AWS Systems Manager Parameter Store.
- An EC2 launch template that configures ECS hosts.
- An Auto Scaling group that runs hosts in the private subnets.
- An ECS capacity provider that connects the Auto Scaling group to the ECS cluster.

Task definitions, ECS services, a load balancer, application images, databases, and monitoring will be added on top of this compute foundation later.

## Amazon Elastic Container Service (ECS)

### What is ECS?

**Amazon Elastic Container Service (ECS)** is AWS's managed container-orchestration service. It coordinates containers: it decides where they run, keeps the desired number of container tasks running, and reports their state.

This project uses the ECS **EC2 launch type**. With this model, AWS manages the ECS control plane while this Terraform configuration provides the EC2 instances that have the CPU, memory, Docker runtime, and ECS agent needed to run containers.

The configuration creates an ECS cluster named `${project_name}-cluster`. A cluster is a logical group of compute capacity where ECS can place application tasks. It does not itself create or run an EC2 instance; the Auto Scaling group provides that capacity.

### ECS control plane and container instances

The ECS control plane is managed by AWS. It receives task requests, tracks the health and state of tasks, and selects an eligible container instance on which to run each task.

The EC2 instances created by this project are called **container instances**. They run in the project's private subnets and register with the cluster when they start. The relationship is:

```text
ECS cluster
  └── ECS capacity provider
        └── Auto Scaling group
              └── EC2 container instances in private subnets
                    └── ECS tasks and application containers
```

Keeping the hosts in private subnets means they do not accept direct connections from the internet. Their outbound access is provided through the networking foundation's NAT instance.

## IAM role and instance profile

### Why do the ECS hosts need an IAM role?

An EC2 instance needs permission to communicate with ECS. For example, the ECS agent must register the instance with the cluster, poll for work, and report task status. AWS permissions are granted through an **IAM role**, rather than by placing permanent access keys on the server.

This module creates the `${project_name}-ecs-instance-role` role. Its trust policy permits the EC2 service to assume the role. The role is then given the AWS-managed `AmazonEC2ContainerServiceforEC2Role` policy, which provides the permissions required by an ECS container instance.

### What is an instance profile?

An **instance profile** is the EC2-specific wrapper that attaches an IAM role to an EC2 instance. This module creates `${project_name}-ecs-instance-profile` and refers to it from the launch template.

When an ECS host starts, applications such as the ECS agent obtain temporary credentials through the EC2 Instance Metadata Service. The credentials are rotated automatically by AWS, so no long-lived AWS secret needs to be stored in the Terraform configuration or on the host.

## Security group for ECS hosts

### What is the ECS host security group?

A **security group** is a stateful virtual firewall applied to an AWS network interface. The module creates `cloud-design-ecs-sg` and attaches it to every EC2 instance launched by the ECS launch template.

The current rules are:

| Direction | Traffic allowed | Purpose |
|---|---|---|
| Inbound | All protocols and ports from the VPC CIDR block | Lets resources inside the VPC communicate with ECS hosts. |
| Outbound | All protocols and ports to `0.0.0.0/0` | Lets hosts reach ECS, pull images, install updates, and communicate with permitted external services through NAT. |

The inbound rule does not permit traffic from the public internet because it is limited to `var.vpc_cidr`. This is appropriate for private compute hosts, but it is intentionally broad within the VPC. As application services are added, it is safer to replace it with rules that only allow the ports and source security groups each workload actually needs.

## ECS-optimised AMI and launch template

### What is the ECS-optimised AMI?

An **Amazon Machine Image (AMI)** is the operating-system image used to create an EC2 instance. Rather than hard-coding an AMI ID, this module looks up AWS's recommended Amazon Linux 2023 ECS-optimised AMI through Systems Manager Parameter Store:

```hcl
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}
```

The ECS-optimised AMI includes the ECS agent and the software needed to run container workloads. Using the public SSM parameter lets new hosts use AWS's current recommended image for the selected region without changing a region-specific AMI ID in source control.

### What is a launch template?

An **EC2 launch template** is a reusable definition for new EC2 instances. The `${project_name}-ecs-template` launch template specifies:

- The ECS-optimised AMI.
- A `t3.small` instance type.
- The ECS host security group.
- The IAM instance profile.
- Instance tags.
- A bootstrap script that assigns the host to the ECS cluster.

The bootstrap script writes the cluster name to `/etc/ecs/ecs.config`:

```bash
echo "ECS_CLUSTER=<project-name>-cluster" >> /etc/ecs/ecs.config
```

On first boot, the ECS agent reads this setting and registers the instance with the cluster created by `aws_ecs_cluster.main`. Without this configuration, the instance would not become usable ECS capacity for this project.

The template also tags each instance with the name `${project_name}-ecs-host`, making the hosts easier to identify in the EC2 console and billing reports.

## Auto Scaling group

### What is an Auto Scaling group?

An **Auto Scaling group (ASG)** maintains a chosen number of EC2 instances. If an instance fails or is terminated, the ASG creates a replacement from its launch template. It is the source of the EC2 capacity used by this ECS cluster.

This module creates an ASG in `var.private_subnet_ids`, which come from the networking module. It is configured with:

| Setting | Value | Meaning |
|---|---:|---|
| Minimum size | `1` | At least one ECS host is kept running. |
| Desired capacity | `1` | One ECS host is launched initially. |
| Maximum size | `3` | The cluster can grow to three ECS hosts. |

Using multiple private subnets lets the ASG distribute instances across Availability Zones when capacity grows. With a desired capacity of one, however, the initial compute capacity is a single host and is not highly available. Increasing the desired and minimum capacity is needed when the application requires host-level resilience.

The `AmazonECSManaged` tag is required for ECS to manage the Auto Scaling group through its capacity provider.

## ECS capacity provider

### What is a capacity provider?

An ECS **capacity provider** connects an ECS cluster to a source of compute capacity. In this project, `${project_name}-capacity-provider` connects the cluster to the Auto Scaling group.

When ECS services use this provider, ECS can evaluate whether the running EC2 hosts have enough reserved CPU and memory for the desired tasks. Managed scaling can then adjust the ASG within its minimum and maximum sizes.

The capacity provider uses a target capacity of `80`. In simple terms, ECS aims to keep the hosts approximately 80% reserved, leaving some headroom for scheduling and short-term growth. Its minimum and maximum scaling step sizes are both `1`, so it adds or removes one host per scaling action.

### Default capacity provider strategy

The cluster configuration sets this provider as the default strategy:

```hcl
default_capacity_provider_strategy {
  base              = 1
  weight            = 100
  capacity_provider = aws_ecs_capacity_provider.ecs.name
}
```

`base = 1` tells ECS to place at least one task using this provider when a service uses the default strategy. `weight = 100` gives this provider full preference because it is currently the cluster's only configured provider.

Future ECS services can rely on this default strategy or explicitly declare the same provider. The capacity provider cannot scale beyond three hosts until the ASG `max_size` is increased.

## Current limitations and next steps

This module creates the platform for running containers, but it does not yet define the containers themselves. Before the microservices can run, the project still needs ECS task definitions and ECS services, including CPU and memory reservations, container images, environment configuration, networking mode, and health checks.

For a production-oriented setup, also consider:

- Using least-privilege security-group rules between the load balancer, services, and databases.
- Enabling instance refreshes so newer ECS-optimised AMIs are adopted safely.
- Configuring CloudWatch logs, metrics, and alarms for the ECS cluster, hosts, and services.
- Using multiple running hosts across Availability Zones for better availability.
- Reviewing the legacy `AmazonEC2ContainerServiceforEC2Role` managed policy and replacing it with a least-privilege role policy where appropriate.
