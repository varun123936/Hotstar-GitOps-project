# Hotstar GitOps - Terraform Resource Refactoring Guide

## Overview
This guide provides specific code changes to rename and improve Terraform resources for better clarity, maintainability, and AWS best practices.

---

## 1. S3 BUCKETS REFACTORING

### Current Issues
- Non-descriptive names: "hotstaarumullaas", "hotstaalurus"
- No indication of purpose
- Ambiguous which bucket stores what state

### Recommended Changes

**File**: `s3-buckets/main.tf`

```hcl
# ❌ BEFORE
resource "aws_s3_bucket" "bucket1" {
  bucket = "hotstaarumullaas"
  tags = {
    Name        = "hotstaarumullaas"
    Environment = "dev"
  }
}

resource "aws_s3_bucket" "bucket2" {
  bucket = "hotstaalurus"
  tags = {
    Name        = "hotstaalurus"
    Environment = "dev"
  }
}

# ✅ AFTER
resource "aws_s3_bucket" "terraform_state_ec2" {
  bucket = "hotstar-terraform-state-ec2-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name        = "hotstar-terraform-state-ec2"
    Environment = "production"
    Purpose     = "Store Terraform state for EC2 Jumphost infrastructure"
  }
}

resource "aws_s3_bucket" "terraform_state_kubernetes" {
  bucket = "hotstar-terraform-state-k8s-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name        = "hotstar-terraform-state-kubernetes"
    Environment = "production"
    Purpose     = "Store Terraform state for EKS and ECR infrastructure"
  }
}

# Add AWS account ID to bucket names (must be globally unique in AWS)
data "aws_caller_identity" "current" {}
```

**File**: `s3-buckets/variables.tf`

```hcl
# ❌ BEFORE
variable "bucket1_name" {
  description = "Name of the first S3 bucket"
  type        = string
  default     = "hotstaarumullaas"
}

variable "bucket2_name" {
  description = "Name of the second S3 bucket"
  type        = string
  default     = "hotstaalurus"
}

# ✅ AFTER
variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "ec2_bucket_name" {
  description = "S3 bucket name for EC2 Terraform state"
  type        = string
  default     = "hotstar-terraform-state-ec2"
}

variable "kubernetes_bucket_name" {
  description = "S3 bucket name for Kubernetes (EKS + ECR) Terraform state"
  type        = string
  default     = "hotstar-terraform-state-k8s"
}

variable "enable_versioning" {
  description = "Enable S3 versioning for disaster recovery"
  type        = bool
  default     = true
}
```

**File**: `s3-buckets/outputs.tf`

```hcl
# ✅ UPDATE
output "ec2_state_bucket_id" {
  description = "ID of the S3 bucket storing EC2 Terraform state"
  value       = aws_s3_bucket.terraform_state_ec2.id
}

output "kubernetes_state_bucket_id" {
  description = "ID of the S3 bucket storing Kubernetes Terraform state"
  value       = aws_s3_bucket.terraform_state_kubernetes.id
}
```

---

## 2. ECR REPOSITORY REFACTORING

### Current Issues
- Generic repository name "hotstar" (unclear if it's for frontend, backend, or entire app)
- No tagging for different image types
- Could have multiple microservices

### Recommended Changes

**File**: `ecr-terraform/ecr-repo-main.tf`

```hcl
# ❌ BEFORE
resource "aws_ecr_repository" "hotstar" {
  name = "hotstar"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Environment = "production"
    Service     = "hotstar"
  }
}

# ✅ AFTER
# For main Hotstar application (React frontend + Node.js backend)
resource "aws_ecr_repository" "hotstar_app" {
  name                 = "hotstar/app"
  image_tag_mutability = "MUTABLE"  # Allow tag overwrites for dev
  
  image_scanning_configuration {
    scan_on_push = true  # Automatic vulnerability detection
  }
  
  encryption_configuration {
    encryption_type = "AES256"  # Encrypt images at rest
  }
  
  tags = {
    Name        = "hotstar-app-repository"
    Environment = "production"
    Application = "hotstar"
    Purpose     = "Store Docker images for Hotstar streaming application"
  }
}

# Optional: Separate repositories for microservices
resource "aws_ecr_repository" "hotstar_api_service" {
  name                 = "hotstar/api-service"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Name        = "hotstar-api-repository"
    Environment = "production"
    Application = "hotstar"
    Purpose     = "Store Docker images for Hotstar API backend service"
  }
}

resource "aws_ecr_repository" "hotstar_cache_service" {
  name                 = "hotstar/cache-service"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  tags = {
    Name        = "hotstar-cache-repository"
    Environment = "production"
    Application = "hotstar"
    Purpose     = "Store Docker images for Hotstar caching service"
  }
}
```

**File**: `ecr-terraform/outputs.tf` (Create this file)

```hcl
output "hotstar_app_repository_url" {
  description = "URL of the Hotstar app ECR repository"
  value       = aws_ecr_repository.hotstar_app.repository_url
}

output "hotstar_api_repository_url" {
  description = "URL of the Hotstar API ECR repository"
  value       = aws_ecr_repository.hotstar_api_service.repository_url
}

output "hotstar_cache_repository_url" {
  description = "URL of the Hotstar Cache ECR repository"
  value       = aws_ecr_repository.hotstar_cache_service.repository_url
}
```

---

## 3. EKS CLUSTER REFACTORING

### Current Issues
- Generic cluster name "project-eks" (could be any project)
- IAM role names use personal names (yaswanth, veera)
- Ambiguous resource purposes
- Node group name not descriptive

### Recommended Changes

**File**: `eks-terraform/main.tf`

```hcl
# ❌ BEFORE - IAM Master Role
resource "aws_iam_role" "master" {
  name = "yaswanth-eks-master1"
  
  assume_role_policy = jsonencode({...})
}

# ✅ AFTER - IAM Master Role
resource "aws_iam_role" "eks_cluster_master" {
  name = "hotstar-eks-cluster-master-role"
  description = "IAM role for Hotstar EKS cluster control plane"
  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole",
        "Condition": {}
      }
    ]
  })
  
  tags = {
    Name        = "hotstar-eks-cluster-master-role"
    Purpose     = "Allows EKS control plane to manage cluster infrastructure"
    Environment = "production"
  }
}

# ❌ BEFORE - IAM Policy Attachments
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master.name
}

# ✅ AFTER - IAM Policy Attachments (Renamed for clarity)
resource "aws_iam_role_policy_attachment" "master_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_master.name
}

resource "aws_iam_role_policy_attachment" "master_eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_master.name
}

resource "aws_iam_role_policy_attachment" "master_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_master.name
}

# --------- WORKER NODE ROLE ---------

# ❌ BEFORE
resource "aws_iam_role" "worker" {
  name = "yaswanth-eks-worker1"
  
  assume_role_policy = jsonencode({...})
}

# ✅ AFTER
resource "aws_iam_role" "eks_worker_node" {
  name = "hotstar-eks-worker-node-role"
  description = "IAM role for Hotstar EKS worker nodes"
  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "hotstar-eks-worker-node-role"
    Purpose     = "Allows EC2 instances to join EKS cluster and pull images"
    Environment = "production"
  }
}

# --------- AUTO-SCALER POLICY ---------

# ❌ BEFORE
resource "aws_iam_policy" "autoscaler" {
  name = "veera-eks-autoscaler-policy1"
  policy = jsonencode({...})
}

# ✅ AFTER
resource "aws_iam_policy" "eks_autoscaler_policy" {
  name        = "hotstar-eks-autoscaler-policy"
  description = "Policy to allow EKS node auto-scaling based on resource demand"
  
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeTags",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  })
}

# --------- WORKER POLICY ATTACHMENTS ---------

# ❌ BEFORE
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker.name
}

# ✅ AFTER
resource "aws_iam_role_policy_attachment" "worker_eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_worker_node.name
}

resource "aws_iam_role_policy_attachment" "worker_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_worker_node.name
}

resource "aws_iam_role_policy_attachment" "worker_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_worker_node.name
}

resource "aws_iam_role_policy_attachment" "worker_s3_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.eks_worker_node.name
}

resource "aws_iam_role_policy_attachment" "worker_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_worker_node.name
}

resource "aws_iam_role_policy_attachment" "worker_autoscaler_policy" {
  policy_arn = aws_iam_policy.eks_autoscaler_policy.arn
  role       = aws_iam_role.eks_worker_node.name
}

# --------- INSTANCE PROFILE ---------

# ❌ BEFORE
resource "aws_iam_instance_profile" "worker" {
  depends_on = [aws_iam_role.worker]
  name       = "yaswanth-eks-worker-new-profile1"
  role       = aws_iam_role.worker.name
}

# ✅ AFTER
resource "aws_iam_instance_profile" "eks_worker_profile" {
  name = "hotstar-eks-worker-instance-profile"
  role = aws_iam_role.eks_worker_node.name
}

# --------- EKS CLUSTER ---------

# ❌ BEFORE
resource "aws_eks_cluster" "eks" {
  name     = "project-eks"
  role_arn = aws_iam_role.master.arn
  
  vpc_config {
    subnet_ids = [data.aws_subnet.subnet-1.id, data.aws_subnet.subnet-2.id]
  }
  
  tags = {
    "Name" = "MyEKS"
  }
}

# ✅ AFTER
resource "aws_eks_cluster" "hotstar_primary" {
  name     = "hotstar-app-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_master.arn
  version  = "1.29"  # Specify Kubernetes version
  
  vpc_config {
    subnet_ids              = [data.aws_subnet.subnet-1.id, data.aws_subnet.subnet-2.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  
  logging_config {
    cloudwatch_log_group_name            = "/aws/eks/hotstar-app"
    cloudwatch_log_group_retention_in_days = 7
    enabled                              = true
    log_types                            = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  }
  
  tags = {
    Name        = "hotstar-app-eks-cluster"
    Environment = "production"
    Application = "hotstar"
    Purpose     = "Kubernetes cluster for Hotstar streaming application"
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.master_eks_cluster_policy,
    aws_iam_role_policy_attachment.master_eks_service_policy,
    aws_iam_role_policy_attachment.master_vpc_resource_controller,
  ]
}

# --------- NODE GROUP ---------

# ❌ BEFORE
resource "aws_eks_node_group" "node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.worker.arn
  subnet_ids      = [data.aws_subnet.subnet-1.id, data.aws_subnet.subnet-2.id]
  
  capacity_type   = "ON_DEMAND"
  disk_size       = 20
  instance_types  = ["t2.small"]
  
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 1
  }
}

# ✅ AFTER
resource "aws_eks_node_group" "hotstar_app_nodes" {
  cluster_name    = aws_eks_cluster.hotstar_primary.name
  node_group_name = "hotstar-app-node-group"
  node_role_arn   = aws_iam_role.eks_worker_node.arn
  subnet_ids      = [data.aws_subnet.subnet-1.id, data.aws_subnet.subnet-2.id]
  version         = aws_eks_cluster.hotstar_primary.version
  
  capacity_type   = "ON_DEMAND"  # Cost: $0.0464/hour per t2.small
  disk_size       = 30           # Increased from 20GB for logs & containers
  instance_types  = ["t2.small"] # 1 vCPU, 2GB RAM each
  
  scaling_config {
    min_size     = 1     # Minimum for cost optimization
    desired_size = 2     # Standard operation: 2 nodes
    max_size     = 10    # Can scale to 10x under load
  }
  
  update_config {
    max_unavailable_percentage = 10  # Roll 1 node at a time during updates
  }
  
  labels = {
    Environment = "production"
    Application = "hotstar"
    NodePool    = "app-workload"
  }
  
  tags = {
    Name        = "hotstar-app-node-group"
    Environment = "production"
    Application = "hotstar"
    Purpose     = "Hotstar application container workloads"
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.worker_eks_node_policy,
    aws_iam_role_policy_attachment.worker_cni_policy,
    aws_iam_role_policy_attachment.worker_registry_policy,
  ]
}
```

---

## 4. EC2 JUMPHOST REFACTORING

### Current Issues
- IAM role named "Jumphost-iam-role1" (generic, unclear purpose)
- Instance profile named after person "yaswanth-profile"
- VPC/subnets/SG named for jumphost but will serve entire infrastructure
- Hard to understand what each resource does

### Recommended Changes

**File**: `terraform_main_ec2/iam-role.tf`

```hcl
# ❌ BEFORE
resource "aws_iam_role" "iam-role" {
  name               = var.iam-role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [...]
}
EOF
}

# ✅ AFTER
resource "aws_iam_role" "jumphost_management" {
  name        = "hotstar-core-jumphost-role"
  description = "IAM role for Hotstar jumphost - CI/CD, infrastructure management, and monitoring"
  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "hotstar-core-jumphost-role"
    Purpose     = "Management server for infrastructure and CI/CD"
    Environment = "production"
  }
}
```

**File**: `terraform_main_ec2/iam-policy.tf`

```hcl
# ❌ BEFORE (Some generic AWS managed policies attached)

# ✅ AFTER (More specific naming and documentation)
resource "aws_iam_role_policy_attachment" "jumphost_eks_policy" {
  role       = aws_iam_role.jumphost_management.name
  policy_arn = aws_iam_policy.eks_policy.arn
  
  depends_on = [aws_iam_policy.eks_policy]
}

resource "aws_iam_role_policy_attachment" "jumphost_admin_access" {
  role       = aws_iam_role.jumphost_management.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# You can optionally restrict this to least privilege later
resource "aws_iam_policy" "eks_policy" {
  name        = "hotstar-jumphost-eks-management-policy"
  description = "Custom policy for EKS cluster management from jumphost"
  
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "eks:*",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "ec2:*",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "autoscaling:*",
        "Resource": "*"
      }
    ]
  })
}
```

**File**: `terraform_main_ec2/iam-instance-profile.tf`

```hcl
# ❌ BEFORE
resource "aws_iam_instance_profile" "instance-profile" {
  name = "yaswanth-profile"
  role = aws_iam_role.iam-role.name
}

# ✅ AFTER
resource "aws_iam_instance_profile" "jumphost_profile" {
  name = "hotstar-core-jumphost-profile"
  role = aws_iam_role.jumphost_management.name
}
```

**File**: `terraform_main_ec2/vpc.tf`

```hcl
# ❌ BEFORE
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc-name  # "Jumphost-vpc"
  }
}

# ✅ AFTER
resource "aws_vpc" "core_network" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "hotstar-core-vpc"
    Purpose     = "Core VPC for Hotstar infrastructure (Jumphost, EKS cluster, RDS future)"
    Environment = "production"
    CIDR        = "10.0.0.0/16"
  }
}

# ❌ BEFORE
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.igw-name  # "Jumphost-igw"
  }
}

# ✅ AFTER
resource "aws_internet_gateway" "core_igw" {
  vpc_id = aws_vpc.core_network.id

  tags = {
    Name        = "hotstar-core-igw"
    Purpose     = "Internet gateway for public subnet routing"
    Environment = "production"
  }
}

# ❌ BEFORE
resource "aws_subnet" "public-subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet-name1  # "Public-Subnet-1"
  }
}

# ✅ AFTER
resource "aws_subnet" "public_primary" {
  vpc_id                  = aws_vpc.core_network.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "hotstar-core-public-subnet-1a"
    Purpose     = "Public subnet for Jumphost, NAT gateway, ALB"
    AZ          = "us-east-1a"
    Environment = "production"
  }
}

resource "aws_subnet" "public_secondary" {
  vpc_id                  = aws_vpc.core_network.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "hotstar-core-public-subnet-1b"
    Purpose     = "Public subnet for redundancy and high availability"
    AZ          = "us-east-1b"
    Environment = "production"
  }
}

# --------- PRIVATE SUBNETS ---------

resource "aws_subnet" "private_primary" {
  vpc_id                  = aws_vpc.core_network.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "hotstar-core-private-subnet-1a"
    Purpose     = "Private subnet for databases, caches, internal services"
    AZ          = "us-east-1a"
    Environment = "production"
  }
}

resource "aws_subnet" "private_secondary" {
  vpc_id                  = aws_vpc.core_network.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = "hotstar-core-private-subnet-1b"
    Purpose     = "Private subnet for databases, caches, internal services"
    AZ          = "us-east-1b"
    Environment = "production"
  }
}

# --------- ROUTE TABLES ---------

# ❌ BEFORE
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = var.rt-name  # "Jumphost-rt"
  }
}

# ✅ AFTER
resource "aws_route_table" "public_routes" {
  vpc_id = aws_vpc.core_network.id
  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.core_igw.id
  }

  tags = {
    Name        = "hotstar-core-public-rt"
    Purpose     = "Route table for internet access via IGW"
    Environment = "production"
  }
}

resource "aws_route_table_association" "public_primary_association" {
  route_table_id = aws_route_table.public_routes.id
  subnet_id      = aws_subnet.public_primary.id
}

resource "aws_route_table_association" "public_secondary_association" {
  route_table_id = aws_route_table.public_routes.id
  subnet_id      = aws_subnet.public_secondary.id
}

# --------- PRIVATE ROUTE TABLE ---------

resource "aws_route_table" "private_routes" {
  vpc_id = aws_vpc.core_network.id

  tags = {
    Name        = "hotstar-core-private-rt"
    Purpose     = "Route table for private subnets (local only initially)"
    Environment = "production"
  }
}

resource "aws_route_table_association" "private_primary_association" {
  route_table_id = aws_route_table.private_routes.id
  subnet_id      = aws_subnet.private_primary.id
}

resource "aws_route_table_association" "private_secondary_association" {
  route_table_id = aws_route_table.private_routes.id
  subnet_id      = aws_subnet.private_secondary.id
}

# --------- SECURITY GROUP ---------

# ❌ BEFORE
resource "aws_security_group" "security-group" {
  vpc_id      = aws_vpc.vpc.id
  description = "Allowing Jenkins, Sonarqube, SSH Access"

  ingress = [...]

  tags = {
    Name = var.sg-name  # "Jumphost-sg"
  }
}

# ✅ AFTER
resource "aws_security_group" "jumphost_management_sg" {
  vpc_id      = aws_vpc.core_network.id
  name        = "hotstar-core-jumphost-sg"
  description = "Security group for Hotstar Jumphost - allows Jenkins, Sonarqube, SSH, EKS management"

  ingress = [
    for port in [22, 80, 443, 8080, 9000, 3000, 8082, 8081] : {
      description      = "Access to port ${port}"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      ipv6_cidr_blocks = ["::/0"]
      self             = false
      prefix_list_ids  = []
      security_groups  = []
      cidr_blocks      = ["0.0.0.0/0"]  # TODO: Restrict to specific IPs in production
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "hotstar-core-jumphost-sg"
    Purpose     = "Jumphost management server security"
    Environment = "production"
  }
}
```

**File**: `terraform_main_ec2/jumphost.tf`

```hcl
# ❌ BEFORE
resource "aws_instance" "ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public-subnet1.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name
  root_block_device {
    volume_size = 30
  }
  user_data = templatefile("./install-tools.sh", {})

  tags = {
    Name = var.instance_name
  }
}

# ✅ AFTER
resource "aws_instance" "jumphost_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_primary.id
  vpc_security_group_ids = [aws_security_group.jumphost_management_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jumphost_profile.name
  
  associate_public_ip_address = true
  monitoring              = true
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 for security
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 50  # Increased for logs and Docker images
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    
    tags = {
      Name = "hotstar-core-jumphost-root-volume"
    }
  }

  user_data = templatefile("${path.module}/install-tools.sh", {})
  
  # CloudWatch monitoring
  credit_specification {
    cpu_credits = "unlimited"  # For t2.large, allow unlimited CPU bursts
  }

  tags = {
    Name        = "hotstar-core-jumphost-server"
    Environment = "production"
    Application = "hotstar"
    Role        = "ci-cd-infrastructure-management"
    Purpose     = "Hosts Jenkins, Terraform, Docker, kubectl, EKS management tools"
  }

  depends_on = [aws_internet_gateway.core_igw]

  lifecycle {
    create_before_destroy = true
  }
}
```

**File**: `terraform_main_ec2/variables.tf`

```hcl
# ❌ BEFORE
variable "vpc-name" {
  description = "VPC Name for our Jumphost server"
  type        = string
  default     = "Jumphost-vpc"
}

variable "iam-role" {
  description = "IAM Role for the Jumphost Server"
  type        = string
  default     = "Jumphost-iam-role1"
}

# ✅ AFTER
variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for core VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet in AZ 1a"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet in AZ 1b"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet in AZ 1a"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet in AZ 1b"
  type        = string
  default     = "10.0.3.0/24"
}

variable "ami_id" {
  description = "AMI ID for the Jumphost EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = "ami-0150ccaf51ab55a51"
}

variable "instance_type" {
  description = "EC2 instance type (2 vCPU, 8GB RAM recommended)"
  type        = string
  default     = "t2.large"
}

variable "key_name" {
  description = "EC2 keypair name for SSH access"
  type        = string
  default     = "us-east-1"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}
```

**File**: `terraform_main_ec2/outputs.tf` (Create if not exists)

```hcl
output "jumphost_instance_id" {
  description = "Instance ID of the Jumphost server"
  value       = aws_instance.jumphost_server.id
}

output "jumphost_public_ip" {
  description = "Public IP address of the Jumphost server"
  value       = aws_instance.jumphost_server.public_ip
}

output "jumphost_private_ip" {
  description = "Private IP address of the Jumphost server"
  value       = aws_instance.jumphost_server.private_ip
}

output "jumphost_public_dns" {
  description = "Public DNS name of the Jumphost server"
  value       = aws_instance.jumphost_server.public_dns
}

output "vpc_id" {
  description = "ID of the core VPC"
  value       = aws_vpc.core_network.id
}

output "public_subnet_1_id" {
  description = "ID of public subnet 1"
  value       = aws_subnet.public_primary.id
}

output "public_subnet_2_id" {
  description = "ID of public subnet 2"
  value       = aws_subnet.public_secondary.id
}

output "security_group_id" {
  description = "ID of Jumphost security group"
  value       = aws_security_group.jumphost_management_sg.id
}
```

---

## Summary of Changes

### Naming Convention Applied
- **AWS Service Prefix**: `hotstar-` (identifies the application)
- **Component Type**: `core`, `app`, `eks`, `ec2` (identifies infrastructure layer)
- **Resource Type**: `vpc`, `sg`, `iam-role`, `instance` (identifies AWS resource)
- **Scope**: `-role`, `-policy`, `-profile` (identifies resource purpose)

### Example:
- `hotstar-core-jumphost-role` = Hotstar's Core infrastructure's Jumphost IAM role
- `hotstar-app-eks-cluster` = Hotstar application's EKS cluster
- `hotstar-terraform-state-k8s` = Hotstar's Terraform state for Kubernetes infrastructure

### Benefits of Refactoring
1. ✅ **Clarity**: Easy to understand what each resource does
2. ✅ **Consistency**: Follows AWS naming best practices
3. ✅ **Scalability**: Easy to add new environments (staging, dev) by changing variable
4. ✅ **Maintenance**: Easier to manage and troubleshoot
5. ✅ **Documentation**: Tags explain purpose and dependencies
6. ✅ **Auditability**: Clear resource ownership and purpose

