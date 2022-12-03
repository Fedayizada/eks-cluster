resource "aws_security_group" "dev-cluster" {
  name        = "dev-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-eks-cluster"
  }
}

# OPTIONAL: Allow inbound traffic from your local workstation external IP
#           to the Kubernetes. You will need to replace A.B.C.D below with
#           your real IP. Services like icanhazip.com can help you find this.
resource "aws_security_group_rule" "cluster-ingress-https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow Everyone to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.dev-cluster.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group" "dev-eks-node" {
  name        = "dev-eks-node-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-eks-node-sg"
  }
}

# OPTIONAL: Allow inbound traffic from your local workstation external IP
#           to the Kubernetes. You will need to replace A.B.C.D below with
#           your real IP. Services like icanhazip.com can help you find this.
resource "aws_security_group_rule" "cluster-node-ingress-https-api" {
  self = true
  description       = "Allow nodes to communicate with other nodes in cluster"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.dev-eks-node.id
  to_port           = 0
  type              = "ingress"
}

resource "aws_security_group_rule" "cluster-node-ingress-https" {
  source_security_group_id = aws_security_group.dev-eks-node.id
  description       = "Allow EKS Node to communicate with EKS API Server"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.dev-cluster.id
  to_port           = 0
  type              = "ingress"
}

resource "aws_security_group_rule" "node-cluster" {
  source_security_group_id = aws_security_group.dev-cluster.id
  description       = "Allow EKS API to communicate with Node"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.dev-eks-node.id
  to_port           = 0
  type              = "ingress"
}

