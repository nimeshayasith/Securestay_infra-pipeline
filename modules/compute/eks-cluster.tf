resource "aws_eks_cluster" "securestay" {
  name     = var.cluster_name
  version  = "1.29"
  role_arn = var.eks_cluster_role_arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = {
    Name        = "securestay-eks"
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.securestay.name
  node_group_name = "securestay-workers"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  # Keep the default worker pool Free Tier-friendly for local/student AWS accounts.
  instance_types = ["t3.micro"]

  update_config {
    max_unavailable = 1
  }

  tags = {
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_eks_cluster.securestay]
}

# Managed add-ons
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.securestay.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.securestay.name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.securestay.name
  addon_name   = "vpc-cni"
  depends_on   = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.securestay.name
  addon_name   = "aws-ebs-csi-driver"
  depends_on   = [aws_eks_node_group.workers]
}
