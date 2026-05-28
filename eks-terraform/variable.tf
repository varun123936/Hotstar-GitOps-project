variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.35"
}

variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "project-eks-node-group"
}
