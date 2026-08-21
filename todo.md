Here is a structured, phase-by-phase roadmap to build out your AWS microservices infrastructure. This provides the big picture of your deployment pipeline.

### **Phase 1 & 2: Foundation & Networking (Completed)**

You have already successfully built the secure skeleton for the project.

- Configured S3 remote state with locking.
- Built a custom VPC with public and private subnets across multiple AZs.
- Deployed a highly cost-optimized custom NAT instance (`fck-nat`) to provide outbound internet access to your private subnets for $0.00/month.

### **Phase 3: The Compute Layer (Amazon ECS & EC2)**

Because the subject requires you to use Docker to build container images for each microservice and deploy them using an orchestration tool like ECS, our next step is to build the cluster.

- **ECS Cluster:** We will create an Amazon ECS Cluster using the **EC2 Launch Type**. (Fargate is generally easier, but running 6 separate containers 24/7 on Fargate will quickly drain your $200 credit pool; EC2 instances are much cheaper to run continuously).
- **Auto Scaling Group (ASG):** We will provision an EC2 instance (likely a `t3.medium` or `t4g.small` to ensure there is enough RAM for all 6 containers) into your private subnets, managed by an ASG.
- **IAM Roles:** We will create the necessary Instance Profiles so your EC2 servers have permission to pull your Docker images and send logs to AWS.

### **Phase 4: The Data & Messaging Containers**

This phase implements the massive correction we just discovered. Instead of managed services, we will orchestrate your stateful services as raw containers inside the ECS cluster.

- **PostgreSQL Containers:** We will write ECS Task Definitions to deploy the `inventory-db` and `billing-db` containers on port `5432`.
- **RabbitMQ Container:** We will write a Task Definition to deploy the `rabbit-queue` container.
- **Service Discovery:** We will configure AWS Cloud Map (Service Discovery) so that your application containers can resolve the internal IP addresses of these databases using simple DNS names (like `[http://inventory-db.local](http://inventory-db.local)`).

### **Phase 5: The Application Layer & Load Balancing**

With the databases running, we will deploy the core business logic.

- **Microservice Deployment:** We will deploy the `inventory-app` (port `8080`), `billing-app` (port `8080`), and the `api-gateway-app` (port `3000`) containers into the cluster.
- **Application Load Balancer (ALB):** We will deploy a public-facing ALB in your public subnets to act as the single entry point for external users, routing traffic directly to the `api-gateway-app`.

### **Phase 6: Security, Auth & Observability**

The final phase focuses on passing the strict audit constraints.

- **AWS Cognito:** We will implement managed authentication to secure your publicly accessible API Gateway, ensuring unauthenticated requests are rejected.
- **Amazon CloudWatch:** We will configure the ECS containers to stream their logs to CloudWatch log groups, setting up the required monitoring and logging tools.
- **Security Groups Tightening:** We will finalize all internal VPC security groups to ensure the databases are strictly inaccessible from the public internet.
