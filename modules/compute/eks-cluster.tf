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

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.securestay.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.securestay.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = {
    Project     = "SecureStay"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.securestay.name
  node_group_name = "securestay-workers"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    min_size     = 2
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
  cluster_name                = aws_eks_cluster.securestay.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.securestay.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.securestay.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.workers]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.securestay.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [
    aws_eks_node_group.workers,
    aws_iam_role_policy_attachment.ebs_csi,
  ]

  timeouts {
    create = "40m"
    update = "40m"
  }
}
