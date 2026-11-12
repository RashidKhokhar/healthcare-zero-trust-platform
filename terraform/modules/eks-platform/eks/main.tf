# HIPAA §164.312(e)(1): private API endpoint only — no public control
# plane access. HIPAA §164.312(a)(2)(iv): Kubernetes Secrets are envelope
# encrypted with a customer-managed KMS key, not just the default AWS key.

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false # no public control-plane exposure
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # HIPAA §164.312(b): control plane audit trail
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_eks_node_group" "primary" {
  cluster_name           = aws_eks_cluster.this.name
  node_group_name        = "${var.cluster_name}-primary"
  node_role_arn          = var.node_role_arn
  subnet_ids             = var.private_subnet_ids # private only — no public-facing nodes
  instance_types         = var.node_instance_types
  vpc_security_group_ids = [aws_security_group.cluster_additional.id]

  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 6
  }

  update_config {
    max_unavailable = 1
  }
}

resource "aws_security_group" "cluster_additional" {
  name_prefix = "${var.cluster_name}-additional-"
  description = "Additional EKS node security group for private intra-VPC communication only."
  vpc_id      = var.vpc_id

  # No 0.0.0.0/0 ingress — HITRUST 09.m network controls
  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Restrict egress to the VPC for workload isolation"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}
