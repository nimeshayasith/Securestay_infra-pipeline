# ── Team IAM Users ────────────────────────────────────────────────────────────

resource "aws_iam_user" "admin" {
  name = "nimesh-admin"
  tags = { Role = "admin", Project = "SecureStay", ManagedBy = "Terraform" }
}

resource "aws_iam_user_policy_attachment" "admin" {
  user       = aws_iam_user.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_user" "readonly" {
  for_each = toset(["member2-readonly", "member3-readonly", "member4-readonly"])
  name     = each.key
  tags     = { Role = "readonly", Project = "SecureStay", ManagedBy = "Terraform" }
}

resource "aws_iam_user_policy_attachment" "readonly" {
  for_each   = aws_iam_user.readonly
  user       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ── EKS Cluster Role ──────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "securestay-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = { Project = "SecureStay", ManagedBy = "Terraform" }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── EKS Node Role — least-privilege (ECR pull + VPC CNI only) ─────────────────

resource "aws_iam_role" "eks_node" {
  name = "securestay-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Project = "SecureStay", ManagedBy = "Terraform" }
}

resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ])
  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}
