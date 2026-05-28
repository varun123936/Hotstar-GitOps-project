# Hotstar GitOps Project - Terraform Infrastructure Analysis

## 🎯 PROJECT OBJECTIVE

The Hotstar GitOps project builds a **complete containerized application deployment infrastructure on AWS** using Infrastructure-as-Code (Terraform). It implements a three-tier architecture:

1. **CI/CD Pipeline Layer** - Jenkins on EC2 for automated builds and deployments
2. **Container Registry Layer** - ECR for storing Docker images
3. **Kubernetes Orchestration Layer** - EKS for running containerized workloads
4. **State Management** - S3 buckets for storing Terraform state files

**High-Level Goal**: Automatically provision, manage, and deploy the Hotstar streaming application across AWS using GitOps principles with Infrastructure-as-Code.

---

## 📊 ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Account (us-east-1)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          VPC (10.0.0.0/16)                           │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ Public Subnets (10.0.0.0/24, 10.0.1.0/24)     │  │   │
│  │  │  ┌──────────────────────────────────────────┐ │  │   │
│  │  │  │ EC2 Jumphost (t2.large)                 │ │  │   │
│  │  │  │ - Jenkins (port 8080)                   │ │  │   │
│  │  │  │ - Terraform                             │ │  │   │
│  │  │  │ - Docker, kubectl, eksctl               │ │  │   │
│  │  │  │ - Sonarqube (port 9000)                 │ │  │   │
│  │  │  │ - ArgoCD, Grafana, Prometheus           │ │  │   │
│  │  │  └──────────────────────────────────────────┘ │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                        ↓                              │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ EKS Cluster (project-eks)                    │  │   │
│  │  │ ┌──────────────────────────────────────────┐ │  │   │
│  │  │ │ Node Group: 2-10 t2.small nodes          │ │  │   │
│  │  │ │ - Running Hotstar application pods       │ │  │   │
│  │  │ │ - Auto-scaling enabled                   │ │  │   │
│  │  │ └──────────────────────────────────────────┘ │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                        │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ Private Subnets (10.0.2.0/24, 10.0.3.0/24)  │  │   │
│  │  │ (Reserved for future components)            │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    ECR Repository (hotstar)                          │   │
│  │    - Stores Docker images of Hotstar app           │   │
│  │    - Image scanning on push enabled                │   │
│  │    - AES256 encryption                             │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    S3 Buckets (Terraform State)                     │   │
│  │    - hotstaarumullaas (EC2 state)                   │   │
│  │    - hotstaalurus (EKS + ECR state)                │   │
│  │    - Both have versioning enabled                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 DETAILED TERRAFORM COMPONENTS

### 1. **S3 BUCKETS - Remote State Storage**
**Location**: `s3-buckets/`

#### Purpose:
- Store Terraform state files remotely (instead of locally)
- Enable team collaboration and consistency
- Track infrastructure changes over time
- Prevent state conflicts among team members

#### Configuration:
```hcl
# S3 Bucket 1: EC2 State
aws_s3_bucket.bucket1 = "hotstaarumullaas"
├── Purpose: Stores EC2 Jumphost infrastructure state
├── Versioning: ENABLED (backup on every change)
├── Region: us-east-1
└── Tags: Environment = dev

# S3 Bucket 2: EKS + ECR State
aws_s3_bucket.bucket2 = "hotstaalurus"
├── Purpose: Stores EKS Cluster & ECR Repository state
├── Versioning: ENABLED
├── Region: us-east-1
└── Tags: Environment = dev
```

**Why Versioning?**
- If Terraform state gets corrupted, you can revert to previous versions
- Tracks infrastructure history
- Disaster recovery capability

**Issues & Recommendations**:
- ❌ **Current Names**: "hotstaarumullaas", "hotstaalurus" (meaningless, unclear purpose)
- ✅ **Recommended Names**:
  - `hotstar-terraform-state-ec2` (for EC2/Jumphost state)
  - `hotstar-terraform-state-eks-ecr` (for EKS and ECR state)

---

### 2. **ECR - Elastic Container Registry**
**Location**: `ecr-terraform/ecr-repo-main.tf`

#### Purpose:
- Private Docker image repository (equivalent to Docker Hub but in AWS)
- Store and manage Hotstar application Docker images
- Secure storage with encryption
- Automatic vulnerability scanning

#### Configuration:
```hcl
resource "aws_ecr_repository" "hotstar" {
  name = "hotstar"
  
  image_scanning_configuration {
    scan_on_push = true  # Auto-scan images for vulnerabilities
  }
  
  encryption_configuration {
    encryption_type = "AES256"  # Encrypt images at rest
  }
  
  tags = {
    Environment = "production"
    Service     = "hotstar"
  }
}
```

**Key Features**:
1. **Image Scanning on Push**: When you push a Docker image, AWS automatically scans for security vulnerabilities
2. **AES256 Encryption**: Images are encrypted when stored (data at rest)
3. **Private Registry**: Only authorized AWS accounts/roles can access images

**Workflow**:
1. Developer pushes code to Git
2. Jenkins builds Docker image
3. Jenkins pushes image to ECR
4. EKS pulls images from ECR to run containers

**Why ECR over Docker Hub?**
- Integrated with AWS (no need for separate credentials)
- Faster image pulls (internal AWS network)
- Better security (AWS IAM integration)
- Automatic image scanning

---

### 3. **EKS - Elastic Kubernetes Service**
**Location**: `eks-terraform/main.tf`

#### Purpose:
- Managed Kubernetes cluster on AWS
- Run containerized Hotstar application with automatic scaling
- Manage deployment, scaling, and networking of containers

#### Key Components:

#### **A) IAM Roles**

```hcl
# EKS Master (Control Plane) Role
aws_iam_role "master" {
  name = "yaswanth-eks-master1"
  
  assume_role_policy: {
    Principal: "eks.amazonaws.com"  # Only EKS service can assume this role
    Action: "sts:AssumeRole"
  }
}

# Attached Policies:
- AmazonEKSClusterPolicy         # Manage cluster
- AmazonEKSServicePolicy          # Network management
- AmazonEKSVPCResourceController  # VPC resource control
```

**What this does**: Allows AWS EKS service to manage cluster infrastructure on your behalf.

---

```hcl
# EKS Worker (Node) Role
aws_iam_role "worker" {
  name = "yaswanth-eks-worker1"
  
  assume_role_policy: {
    Principal: "ec2.amazonaws.com"  # Only EC2 service can assume
    Action: "sts:AssumeRole"
  }
}

# Attached Policies:
- AmazonEKSWorkerNodePolicy              # Worker node permissions
- AmazonEKS_CNI_Policy                   # Container networking (pods communication)
- AmazonSSMManagedInstanceCore           # Systems Manager access (remote SSH)
- AmazonEC2ContainerRegistryReadOnly     # Pull images from ECR
- AmazonS3ReadOnlyAccess                 # Read S3 buckets (app data)
- Custom autoscaler policy               # Auto-scale nodes based on load
```

**What this does**: Allows EC2 nodes to join the cluster, pull images, and scale automatically.

---

#### **B) Auto-Scaler Policy**

```hcl
resource "aws_iam_policy" "autoscaler" {
  name = "veera-eks-autoscaler-policy1"
  
  actions: [
    "autoscaling:DescribeAutoScalingGroups",
    "autoscaling:SetDesiredCapacity",        # Scale up/down nodes
    "autoscaling:TerminateInstanceInAutoScalingGroup"  # Remove nodes
  ]
}
```

**Why?** When Kubernetes needs more resources (high CPU/memory), this policy allows automatic addition of new EC2 nodes.

---

#### **C) EKS Cluster**

```hcl
resource "aws_eks_cluster" "eks" {
  name     = "project-eks"
  role_arn = aws_iam_role.master.arn  # Use master role created above
  
  vpc_config {
    subnet_ids = [subnet-1, subnet-2]  # Deploy in 2 subnets (high availability)
  }
}
```

**High Availability**: Deployed across 2 availability zones (us-east-1a, us-east-1b) for fault tolerance.

---

#### **D) Node Group**

```hcl
resource "aws_eks_node_group" "node-grp" {
  cluster_name    = "project-eks"
  node_group_name = "project-eks-node-group"
  node_role_arn   = aws_iam_role.worker.arn
  
  capacity_type   = "ON_DEMAND"       # Always-on billing (not spot)
  instance_types  = ["t2.small"]      # Instance type (1 vCPU, 2GB RAM each)
  disk_size       = 20                # 20GB storage per node
  
  scaling_config {
    min_size     = 1                  # Minimum nodes
    desired_size = 2                  # Normally run 2 nodes
    max_size     = 10                 # Max scale to 10 nodes under load
  }
}
```

**Scaling Logic**:
- **Minimum**: 1 node (cost optimization)
- **Desired**: 2 nodes (baseline for Hotstar app)
- **Maximum**: 10 nodes (handle 5x traffic spikes)

---

#### **E) OIDC Provider (IAM Roles for Service Accounts)**

```hcl
data "aws_eks_cluster" "eks_oidc" {
  name = aws_eks_cluster.eks.name
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  url             = eks_cluster.identity.oidc.issuer
}
```

**Purpose**: 
- Allows Kubernetes pods to assume AWS IAM roles
- Example: A pod needing S3 access can get temporary AWS credentials
- Better security than hardcoding AWS keys in pods

---

### 4. **EC2 JUMPHOST - CI/CD & Management Server**
**Location**: `terraform_main_ec2/`

#### Purpose:
- Central server for managing entire infrastructure
- Runs Jenkins (CI/CD pipeline)
- Provides tools for infrastructure management
- Acts as gateway/bastion for cluster access

#### Architecture:

#### **A) VPC (Virtual Private Cloud)**

```hcl
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"  # 65,536 IP addresses
  enable_dns_support   = true            # Use AWS DNS
  enable_dns_hostnames = true
}
```

**Network Structure**:
```
VPC: 10.0.0.0/16 (65,536 IPs)
├── Public Subnet 1: 10.0.1.0/24 (256 IPs) - us-east-1a
│   └── EC2 Jumphost
├── Public Subnet 2: 10.0.0.0/24 (256 IPs) - us-east-1b
├── Private Subnet 1: 10.0.2.0/24 (256 IPs) - us-east-1a
└── Private Subnet 2: 10.0.3.0/24 (256 IPs) - us-east-1b
```

**Why 4 Subnets?**
- **Public Subnets**: Host EC2 for internet access
- **Private Subnets**: Reserved for future internal services (databases, caches, etc.)
- **2 Availability Zones**: Resilience if entire zone fails

---

#### **B) Internet Gateway & Routing**

```hcl
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "rt" {
  route {
    cidr_block = "0.0.0.0/0"        # All internet traffic
    gateway_id = aws_internet_gateway.igw.id
  }
}

aws_route_table_association {
  subnet_id      = public_subnet1.id
  route_table_id = rt.id
}
```

**Result**: Public subnets can reach internet (and be reached from internet)

---

#### **C) Security Group**

```hcl
resource "aws_security_group" "security-group" {
  ingress = [
    22,    # SSH (remote access)
    80,    # HTTP (web)
    443,   # HTTPS (secure web)
    8080,  # Jenkins web UI
    9000,  # Sonarqube
    3000,  # Grafana
    8082,  # Jenkins agent
    8081   # Nexus artifact repository
  ]
  
  egress {
    all outbound traffic allowed
  }
}
```

**Security**: Only specific ports are open; all others are blocked.

---

#### **D) EC2 Instance**

```hcl
resource "aws_instance" "ec2" {
  ami                    = "ami-0150ccaf51ab55a51"  # Amazon Linux 2023
  instance_type          = "t2.large"               # 2 vCPU, 8GB RAM
  key_name               = "us-east-1"              # SSH key
  subnet_id              = public_subnet1.id        # Place in public subnet
  vpc_security_group_ids = [security_group.id]      # Apply security rules
  iam_instance_profile   = instance_profile.name    # Attach IAM role
  
  root_block_device {
    volume_size = 30  # 30GB disk
  }
  
  user_data = templatefile("./install-tools.sh", {})
}
```

**What Happens**:
1. AWS launches Amazon Linux 2023 AMI
2. Executes `install-tools.sh` script to install all tools
3. Instance starts with pre-installed Jenkins, Docker, Terraform, etc.

---

#### **E) Installed Tools (install-tools.sh)**

```bash
#!/bin/bash

# System Updates
sudo yum update -y

# Development Tools
- Git          # Version control
- Java 21      # Jenkins requirement
- Maven        # Java build tool

# Infrastructure Tools
- Terraform    # IaC management
- kubectl      # Kubernetes management
- eksctl       # EKS cluster management
- Helm         # Kubernetes package manager

# CI/CD Tools
- Jenkins      # Continuous Integration/Deployment

# Container & Registry
- Docker       # Container runtime
- Trivy        # Container vulnerability scanner

# Code Quality & Monitoring
- Sonarqube    # Code quality analysis
- Prometheus   # Metrics collection
- Grafana      # Monitoring visualization

# Kubernetes Apps (ArgoCD)
- ArgoCD       # GitOps deployment tool
```

**Complete Pipeline Flow**:
```
Git Commit
    ↓
Jenkins (on Jumphost) detects change
    ↓
Runs tests & builds Docker image
    ↓
Scans image with Trivy
    ↓
Pushes image to ECR
    ↓
ArgoCD detects ECR image update
    ↓
Deploys new image to EKS
    ↓
Kubernetes auto-scales if needed
    ↓
Hotstar App running on EKS ✓
```

---

#### **F) IAM Roles for Jumphost**

```hcl
resource "aws_iam_role" "iam-role" {
  assume_role_policy: {
    Principal: "ec2.amazonaws.com"
    Action: "sts:AssumeRole"
  }
}

# Attached Policies:
- AdministratorAccess               # Full AWS access
- AmazonEC2FullAccess               # Manage EC2
- AmazonEKSClusterPolicy            # Manage EKS
- AmazonEKSWorkerNodePolicy         # Worker node access
- AWSCloudFormationFullAccess       # CloudFormation (infrastructure)
- IAMFullAccess                     # Manage IAM roles
- EKS full access policy            # Custom EKS policy
```

**Why so much access?** The Jumphost is a management server that needs to:
- Create/update infrastructure
- Manage Kubernetes clusters
- Deploy applications
- Monitor systems

---

## 📋 DATA SOURCES (Terraform References)

```hcl
# EKS uses existing VPC and subnets created by EC2 module:

data "aws_vpc" "main" {
  tags = { Name = "Jumphost-vpc" }
}
# ↓ Finds the VPC created by terraform_main_ec2

data "aws_subnet" "subnet-1" {
  filter { values = ["Public-Subnet-1"] }
}
# ↓ Finds public subnet 1 created by terraform_main_ec2

data "aws_subnet" "subnet-2" {
  filter { values = ["Public-subnet2"] }
}
# ↓ Finds public subnet 2 created by terraform_main_ec2
```

**Why?** Each Terraform module is independent. EKS module needs to reference VPC created by EC2 module.

---

## 🔄 TERRAFORM BACKEND CONFIGURATION

**Location**: `backend.tf` files in each module

```hcl
# terraform_main_ec2/terraform.tf
backend "s3" {
  bucket = "hotstaarumullaas"
  key    = "ec2/terraform.tfstate"
  region = "us-east-1"
}

# eks-terraform/backend.tf
backend "s3" {
  bucket = "hotstaalurus"
  key    = "k8/terraform.tfstate"
  region = "us-east-1"
}

# ecr-terraform/backend.tf
backend "s3" {
  bucket = "hotstaalurus"
  key    = "ecr/terraform.tfstate"
  region = "us-east-1"
}
```

**What this means**:
- EC2 state stored in `hotstaarumullaas/ec2/terraform.tfstate`
- EKS state stored in `hotstaalurus/k8/terraform.tfstate`
- ECR state stored in `hotstaalurus/ecr/terraform.tfstate`

**Execution Order**:
1. **First**: Run `terraform apply` in `terraform_main_ec2/` (creates VPC, EC2)
2. **Second**: Run `terraform apply` in `ecr-terraform/` (creates ECR)
3. **Third**: Run `terraform apply` in `eks-terraform/` (creates EKS, references VPC from step 1)

---

## 🚨 RESOURCE NAMING ISSUES & FIXES

### Current Problems:

| Component | Current Name | Issue |
|-----------|-------------|-------|
| S3 Bucket 1 | `hotstaarumullaas` | Meaningless, unclear purpose |
| S3 Bucket 2 | `hotstaalurus` | Meaningless, unclear purpose |
| Master IAM Role | `yaswanth-eks-master1` | Personal name, not descriptive |
| Worker IAM Role | `yaswanth-eks-worker1` | Personal name, not descriptive |
| Auto-scaler Policy | `veera-eks-autoscaler-policy1` | Personal name, number suffix |
| Worker Profile | `yaswanth-eks-worker-new-profile1` | Personal name, confusing suffix |
| Jumphost IAM Role | `Jumphost-iam-role1` | Okay, but could be more descriptive |
| EC2 Instance Profile | `yaswanth-profile` | Too generic |
| EKS Cluster | `project-eks` | Too generic |

---

## ✅ RECOMMENDED RENAMING SCHEME

### S3 Buckets
```hcl
# BEFORE
bucket = "hotstaarumullaas"
bucket = "hotstaalurus"

# AFTER
bucket = "hotstar-terraform-state-ec2-prod"
bucket = "hotstar-terraform-state-k8s-prod"
```

### IAM Roles & Policies
```hcl
# BEFORE
name = "yaswanth-eks-master1"
name = "yaswanth-eks-worker1"
name = "veera-eks-autoscaler-policy1"
name = "yaswanth-eks-worker-new-profile1"

# AFTER
name = "hotstar-eks-cluster-master-role"
name = "hotstar-eks-worker-node-role"
name = "hotstar-eks-autoscaler-policy"
name = "hotstar-eks-worker-instance-profile"
```

### EKS Resources
```hcl
# BEFORE
name = "project-eks"
node_group_name = "project-eks-node-group"

# AFTER
name = "hotstar-app-eks-cluster"
node_group_name = "hotstar-app-node-group"
```

### EC2 Resources
```hcl
# BEFORE
name = "Jumphost-iam-role1"
name = "yaswanth-profile"
name = "Jumphost-vpc"
name = "Jumphost-igw"
name = "Jumphost-sg"

# AFTER
name = "hotstar-jumphost-iam-role"
name = "hotstar-jumphost-instance-profile"
name = "hotstar-core-vpc"
name = "hotstar-core-igw"
name = "hotstar-core-security-group"
```

---

## 📊 DEPLOYMENT WORKFLOW

```
1. INITIALIZE S3 BACKEND
   └─ Create S3 buckets for state storage
   └─ Enable versioning

2. DEPLOY EC2 INFRASTRUCTURE (terraform_main_ec2/)
   ├─ Create VPC with subnets
   ├─ Launch Jumphost EC2 instance
   ├─ Install Jenkins, Docker, kubectl, Terraform
   └─ State stored in S3: hotstaarumullaas/ec2/

3. DEPLOY ECR (ecr-terraform/)
   ├─ Create Docker image repository
   ├─ Enable image scanning
   └─ State stored in S3: hotstaalurus/ecr/

4. DEPLOY EKS (eks-terraform/)
   ├─ Create EKS cluster (references VPC from step 2)
   ├─ Create node group (2-10 auto-scaling nodes)
   ├─ Configure OIDC for IAM integration
   └─ State stored in S3: hotstaalurus/k8/

5. JENKINS PIPELINE RUNS (on Jumphost)
   ├─ Build app → Docker image
   ├─ Push image → ECR
   ├─ Deploy → EKS via ArgoCD
   └─ Auto-scale based on demand

6. APPLICATION RUNNING
   └─ Hotstar accessible to users
   └─ Prometheus monitoring
   └─ Grafana dashboards
   └─ ArgoCD for GitOps management
```

---

## 🎯 KEY TAKEAWAYS

| Layer | Component | Purpose |
|-------|-----------|---------|
| **State** | 2 S3 buckets | Store Terraform state safely |
| **Compute** | EC2 Jumphost | Management & CI/CD server |
| **Network** | VPC + Subnets | Isolated network infrastructure |
| **Registry** | ECR | Store Docker images securely |
| **Orchestration** | EKS Cluster | Run containerized app at scale |
| **Automation** | Jenkins + ArgoCD | Continuous deployment pipeline |
| **Monitoring** | Prometheus + Grafana | Observe system health |

---

## 🔒 Security Considerations

1. **IAM Roles**: Least privilege principle should be applied more strictly
2. **Security Groups**: Currently allows broad access (0.0.0.0/0) on multiple ports
3. **S3 State**: Should enable encryption and block public access
4. **EKS OIDC**: Good practice for pod-to-AWS service integration
5. **Image Scanning**: ECR scanning enabled for vulnerability detection

---

## 📈 Scaling & High Availability

- **EKS Multi-AZ**: Cluster spans 2 availability zones
- **Node Auto-scaling**: 1-10 nodes based on CPU/memory demand
- **On-Demand Instances**: Reliable (not spot instances)
- **Versioning**: S3 state versioning prevents corruption
- **Private Subnets**: Future use for databases and internal services

