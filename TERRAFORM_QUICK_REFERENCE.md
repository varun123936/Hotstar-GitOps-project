# Hotstar GitOps - Quick Reference & Deployment Checklist

## 🗺️ Quick Reference Map

### Project Structure
```
Hotstar-GitOps-project/
├── s3-buckets/
│   ├── main.tf (S3 bucket creation & versioning)
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfstate (⚠️ Remove from git, should be in S3!)
│
├── terraform_main_ec2/
│   ├── terraform.tf (Backend: hotstaarumullaas/ec2/)
│   ├── vpc.tf (VPC, Subnets, IGW, Route Tables, Security Groups)
│   ├── jumphost.tf (EC2 instance)
│   ├── iam-role.tf (IAM role for EC2)
│   ├── iam-policy.tf (IAM policies & attachments)
│   ├── iam-instance-profile.tf (Instance profile)
│   ├── variables.tf
│   ├── install-tools.sh (Bootstrap script for Jenkins, Docker, etc.)
│   └── outputs.tf
│
├── ecr-terraform/
│   ├── backend.tf (Backend: hotstaalurus/ecr/)
│   ├── ecr-repo-main.tf (ECR repository)
│   └── (Jenkinsfile for ECR pipeline)
│
├── eks-terraform/
│   ├── backend.tf (Backend: hotstaalurus/k8/)
│   ├── main.tf (EKS cluster, node group, IAM roles, OIDC provider)
│   ├── variable.tf
│   └── (Jenkinsfile for EKS pipeline)
│
├── kubernetes-files/
│   ├── deployment.yml (Kubernetes deployment)
│   └── service.yml (Kubernetes service)
│
├── jenkinsfiles/
│   └── hotstar (CI/CD pipeline definition)
│
└── src/ (Application source code)
    ├── App.js, App.css (React frontend)
    ├── components/ (React components)
    ├── index.js
    └── ... (other app files)
```

---

## 📊 Architecture Decision Matrix

| Layer | Component | Purpose | Current State | Status |
|-------|-----------|---------|----------------|--------|
| **Storage** | S3 | Terraform state backend | Needs renaming | ⚠️ |
| **Compute** | EC2 | Jumphost (CI/CD, management) | Running Jenkins | ✅ |
| **Network** | VPC | Isolated network | 4 subnets (2 public, 2 private) | ✅ |
| **Registry** | ECR | Docker image storage | Created, scan on push enabled | ✅ |
| **Orchestration** | EKS | Kubernetes cluster | 2-10 nodes auto-scaling | ⚠️ Naming |
| **Automation** | Jenkins | Build & deploy pipeline | Installed on Jumphost | ✅ |
| **Deployment** | ArgoCD | GitOps automation | Installed on Jumphost | ✅ |
| **Monitoring** | Prometheus+Grafana | Observability | Installed on Jumphost | ✅ |

---

## 🔑 Key Concepts Explained

### 1. **Infrastructure-as-Code (IaC)**
**What**: Using code to define and manage infrastructure instead of manual AWS console clicks
**Why**: Reproducible, version-controlled, auditable infrastructure
**How**: Terraform declares resources in `.tf` files, `terraform apply` creates them

### 2. **State Files**
**What**: Terraform's record of deployed infrastructure
**Where**: Stored in S3 buckets for team collaboration
**Why**: Terraform needs to know what's already deployed to plan changes
**Important**: Never edit manually, never delete, always version control

### 3. **Modules**
**What**: Self-contained Terraform code folders (s3-buckets/, ec2/, eks/, ecr/)
**Why**: Separation of concerns, reusability, independent scaling
**Dependency**: EC2 creates VPC → EKS references that VPC

### 4. **IAM Roles & Policies**
**What**: AWS permissions system
**Role**: "Who can perform actions"
**Policy**: "What actions are allowed"
**Example**: EKS Cluster Role = "EKS service can manage resources"

### 5. **Availability Zones (AZ)**
**What**: Separate data centers within a region
**Why**: If one AZ fails, the other continues working
**Example**: EKS in 2 AZs (us-east-1a, us-east-1b) = high availability

### 6. **Auto-Scaling**
**What**: Automatically add/remove resources based on demand
**Metrics**: CPU usage, Memory usage, Request count
**Example**: EKS: 1-10 nodes based on CPU > 70%

### 7. **GitOps**
**What**: Git repository is the single source of truth
**Workflow**: Push code → Git → Jenkins → Deploy to EKS → ArgoCD syncs
**Benefit**: Automatic, auditable, reversible deployments

### 8. **Container Orchestration**
**What**: Kubernetes (EKS) manages containerized applications
**Does**: Deploy, scale, update, heal containers automatically
**Example**: Deploy app to 2 replicas → Kubernetes runs on 2 nodes with auto-failover

---

## 🚀 Deployment Sequence

### Phase 1: Foundation (Week 1)
```bash
cd terraform_main_ec2/
terraform init
terraform plan
terraform apply

# Creates: VPC, Subnets, IGW, Security Groups, Jumphost EC2
# Installs: Jenkins, Docker, Terraform, kubectl, eksctl on EC2
```

**Validation**:
- ✅ EC2 running: `aws ec2 describe-instances --region us-east-1`
- ✅ SSH to instance: `ssh -i your-key.pem ec2-user@<public-ip>`
- ✅ Jenkins web UI: `http://<public-ip>:8080`

---

### Phase 2: Container Registry (Week 1)
```bash
cd ecr-terraform/
terraform init
terraform plan
terraform apply

# Creates: ECR repository for Docker images
```

**Validation**:
- ✅ ECR created: `aws ecr describe-repositories --region us-east-1`
- ✅ Push test image: `docker push <account>.dkr.ecr.us-east-1.amazonaws.com/hotstar:test`

---

### Phase 3: Kubernetes Cluster (Week 1-2)
```bash
cd eks-terraform/
terraform init
terraform plan
terraform apply

# Creates: EKS cluster, node group, IAM roles, security groups
# Time: 10-15 minutes for cluster to be ready
```

**Validation**:
- ✅ Cluster created: `aws eks describe-cluster --name project-eks --region us-east-1`
- ✅ Get kubeconfig: `aws eks update-kubeconfig --name project-eks --region us-east-1`
- ✅ Check nodes: `kubectl get nodes`
- ✅ Expected output: 2 nodes in "Ready" state

---

### Phase 4: Application Deployment (Week 2)
```bash
# From Jumphost, configure kubectl
aws eks update-kubeconfig --name project-eks --region us-east-1

# Apply Kubernetes manifests
kubectl apply -f kubernetes-files/deployment.yml
kubectl apply -f kubernetes-files/service.yml

# Check deployment
kubectl get deployments
kubectl get pods
kubectl get svc
```

**Validation**:
- ✅ Deployment running: `kubectl get pods`
- ✅ Service has external IP: `kubectl get svc`
- ✅ App accessible: `curl http://<service-external-ip>`

---

### Phase 5: CI/CD Pipeline (Week 2-3)
```
Configure Jenkins with:
├── GitHub webhook (push triggers build)
├── Build stage (run tests, compile code)
├── Docker stage (build Docker image)
├── Security stage (scan with Trivy)
├── Registry stage (push to ECR)
└── Deploy stage (apply to EKS via ArgoCD)
```

**Pipeline Flow**:
```
Git Commit 
  → Jenkins detects 
    → Build Docker image 
      → Push to ECR 
        → ArgoCD detects 
          → Deploy to EKS 
            → App running ✓
```

---

## ⚙️ Configuration Management

### Terraform Variables (terraform.tfvars)
```hcl
# Create file: terraform.tfvars in each module directory

# terraform_main_ec2/terraform.tfvars
region            = "us-east-1"
vpc_cidr          = "10.0.0.0/16"
ami_id            = "ami-0150ccaf51ab55a51"  # Amazon Linux 2023
instance_type     = "t2.large"
environment       = "production"

# eks-terraform/terraform.tfvars
node_group_name   = "hotstar-app-node-group"
```

### Environment Variables (for Terraform CLI)
```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=your-aws-profile
export TF_VAR_environment=production
```

### AWS Credentials (.aws/credentials)
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY

[hotstar]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

---

## 🔍 Troubleshooting Guide

### Issue: Terraform State Lock
```bash
# Problem: Another person applying, state is locked
# Solution: Check lock, force unlock if needed
terraform force-unlock <lock-id>

# Better: Use S3 state lock (already configured)
```

### Issue: EKS Cluster Not Connecting
```bash
# Problem: kubectl can't reach cluster
# Solution: Update kubeconfig
aws eks update-kubeconfig --name hotstar-app-eks-cluster --region us-east-1

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

### Issue: Nodes Not Starting
```bash
# Problem: Node group in failed state
# Solution: Check IAM role permissions, security groups
aws eks describe-nodegroup --cluster-name hotstar-app-eks-cluster --nodegroup-name hotstar-app-node-group

# Check EC2 instances launching
aws ec2 describe-instances --filters "Name=tag:aws:eks:cluster-name,Values=hotstar-app-eks-cluster"
```

### Issue: ECR Image Push Fails
```bash
# Problem: Permission denied pushing to ECR
# Solution: Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Then push image
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/hotstar:latest
```

### Issue: Jenkins Can't Deploy
```bash
# Problem: Jenkins role doesn't have EKS permissions
# Solution: Update IAM policy attached to Jumphost role (see refactoring guide)

# Verify from Jumphost
aws sts get-caller-identity
kubectl get nodes
```

---

## 📈 Monitoring & Logging

### CloudWatch Logs
```bash
# EKS Cluster Logs
aws logs describe-log-groups --query 'logGroups[*].[logGroupName]'

# Watch real-time logs
aws logs tail /aws/eks/hotstar-app --follow
```

### Prometheus Metrics
```bash
# Access Prometheus dashboard
http://<jumphost-public-ip>:9090

# Query: container_cpu_usage_seconds_total
# Query: container_memory_usage_bytes
```

### Grafana Dashboards
```bash
# Access Grafana
http://<jumphost-public-ip>:3000
# Default credentials: admin/admin

# Dashboards show:
- Cluster health
- Node utilization
- Pod metrics
- Application performance
```

---

## 🛡️ Security Checklist

- [ ] S3 bucket versioning enabled (state recovery)
- [ ] S3 bucket encryption enabled (data at rest)
- [ ] S3 bucket public access blocked
- [ ] EKS cluster logs sent to CloudWatch
- [ ] ECR image scanning enabled
- [ ] Security group rules restricted (not 0.0.0.0/0 for SSH)
- [ ] IAM roles follow least privilege principle
- [ ] EKS OIDC provider configured (pod-to-AWS auth)
- [ ] kubectl RBAC configured (who can access cluster)
- [ ] Secrets managed via AWS Secrets Manager (not in code)
- [ ] Network policies configured in Kubernetes
- [ ] Pod security policies enforced

---

## 📊 Cost Estimation (Monthly, us-east-1)

| Resource | Type | Cost/month | Notes |
|----------|------|-----------|-------|
| S3 | Storage | $1-5 | Small terraform state files |
| EC2 | t2.large | $60 | Jumphost always running |
| EKS | Cluster | $73 | Fixed cluster fee |
| EKS Nodes | 2x t2.small | $28 | Auto-scales to 10x during peak |
| ECR | Storage | $1-10 | Depends on image size & count |
| Data Transfer | Egress | $10-50 | Outbound to users |
| **Total** | **Minimum** | **~$170-200** | **Without scaling** |
| **Total** | **Peak (10 nodes)** | **~$300-400** | **With auto-scaling** |

**Cost Optimization Tips**:
1. Use spot instances for non-critical workloads (save 70%)
2. Auto-scale based on actual demand
3. Use t2.small/medium instances (burstable)
4. Clean up unused ECR images
5. Monitor data transfer (largest cost driver)

---

## 🎯 Next Steps

### Immediate (This Week)
- [ ] Review Terraform code with team
- [ ] Implement renaming scheme (see refactoring guide)
- [ ] Test `terraform plan` on each module
- [ ] Document custom variables for your environment

### Short-term (Next 2 Weeks)
- [ ] Deploy infrastructure in dev environment first
- [ ] Test Jenkins CI/CD pipeline
- [ ] Verify ArgoCD GitOps workflow
- [ ] Load test auto-scaling behavior

### Medium-term (This Month)
- [ ] Implement monitoring dashboards
- [ ] Set up AlertManager for critical issues
- [ ] Create runbooks for common issues
- [ ] Train team on infrastructure management

### Long-term (This Quarter)
- [ ] Implement CI/CD best practices
- [ ] Add database layer (RDS) in private subnets
- [ ] Implement network policies in Kubernetes
- [ ] Set up disaster recovery procedures

---

## 📚 Resources & Documentation

### Official AWS Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)

### Terraform Best Practices
- Use variables for environment-specific values
- Use outputs for cross-module communication
- Use remote state for team collaboration
- Use versions (terraform and providers)
- Use workspaces for environment separation

### Security Best Practices
- Never hardcode credentials
- Use IAM roles instead of access keys
- Enable logging for audit trails
- Use encryption at rest and in transit
- Implement least privilege access

---

## 🤝 Team Collaboration Guidelines

### Git Workflow
```bash
# Branch naming
feature/iam-role-update
bugfix/security-group-fix
hotfix/state-corruption

# Commit message
"terraform(eks): Rename master role to hotstar-eks-cluster-master-role for clarity"

# PR template includes
- Description of changes
- AWS resources affected
- Testing performed
- Rollback plan
```

### Terraform Workflow
```bash
# Before applying changes
terraform fmt -recursive      # Format code
terraform validate            # Check syntax
terraform plan > plan.txt     # Save plan for review
# → Peer review plan.txt

# After approval
terraform apply plan.txt      # Apply saved plan
```

### Documentation Requirements
- Every Terraform module needs a README
- Every IAM policy documented in code
- Every custom script commented
- Architecture diagrams in README

---

## 🎓 Learning Path

**Week 1**: AWS & Terraform Basics
- AWS EC2, VPC, IAM, S3 concepts
- Terraform state, modules, providers

**Week 2**: EKS & Kubernetes
- EKS architecture, node groups, OIDC
- Kubernetes deployments, services, namespaces

**Week 3**: CI/CD & GitOps
- Jenkins pipeline configuration
- ArgoCD GitOps workflow

**Week 4**: Operations & Monitoring
- Prometheus metrics collection
- Grafana dashboards
- CloudWatch logs and alarms

