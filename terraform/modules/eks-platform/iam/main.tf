# HIPAA §164.312(a)(1) / §164.312(a)(2)(i): least-privilege access, unique
# identity per workload. Pods assume scoped IAM roles via IRSA rather than
# nodes sharing a single broad instance profile.

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Example IRSA role: scoped to exactly what one PHI-handling service needs
# (read-only Secrets Manager access to its own secret path) — not a
# blanket admin policy. This is the pattern every workload role should follow.
resource "aws_iam_role" "phi_service_irsa_example" {
  name = "${var.cluster_name}-phi-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = "REPLACE_WITH_EKS_OIDC_PROVIDER_ARN"
      }
      Condition = {
        StringEquals = {
          "REPLACE_WITH_OIDC_URL:sub" = "system:serviceaccount:phi-workloads:phi-service-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "phi_service_scoped_secrets" {
  name = "${var.cluster_name}-phi-service-secrets-policy"
  role = aws_iam_role.phi_service_irsa_example.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:phi-service/*"
    }]
  })
}
