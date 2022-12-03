
data "aws_availability_zones" "available" {
}
data "aws_region" "eks" {
  
}

  terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
}




provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.eks_name]
      command     = "aws"
    }
  }
  version = "2.5.1"

}

provider "kubernetes" {

  host                   = module.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.eks_name]
    command     = "aws"
  }
  version = "2.13.1"
}

module "vpc" {
  source = "../aws-eks-module/modules/aws-vpc-module/"

  name = "eks-vpc"
  cidr = "10.100.0.0/16"



  public_subnet_tags = {
    "kubernetes.io/cluster/dev-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }

  tags = {
    Owner       = "admin"
    Environment = "dev"
    auto-delete = "no"
  }

  vpc_tags = {
    Name = "eks-vpc"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/dev-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"       = "1"
  }
  
}

module "eks_iam" {
  source = "../aws-eks-module/modules/eks-iam-module/"
  oidc_url = module.eks_cluster.eks_identity[0].oidc[0].issuer
  eks_name = "dev-eks-cluster"
  self_managed_node = false
}

module "eks_alb_controller" {
  source = "../aws-eks-module/modules/aws_alb_controller_module/"
  eks_oidc_arn = module.eks_iam.eks_oidc_arn
  eks_oidc_url = module.eks_iam.eks_oidc_url
  eks_name = module.eks_cluster.eks_name
  region = data.aws_region.eks.name
  vpc_id = module.vpc.vpc_id
}
module "eks_cluster" {
  depends_on = [
    module.vpc
  ]
  source = "../aws-eks-module/modules/aws-eks-module/"
  eks_name = "dev-eks-cluster"
  eks_version = "1.24"
  min_size = 0
  eks_subnets = concat(module.vpc.private_subnets , module.vpc.public_subnets)
  eks_sg_ids = ["${aws_security_group.dev-cluster.id}"]
  role_arn = module.eks_iam.eks_iam_role_arn
  node_subnet_ids = module.vpc.private_subnets
  node_sg_ids = [aws_security_group.dev-eks-node.id]
  node_role_arn = module.eks_iam.eks_node_iam_role_arn
  node_group_name = "eks-mng-node"
  launch_template_name = "eks-mng-node-lt"
  create_arm_nodegroup = false
  create_amd_nodegroup = false
  tags = {
    "auto-delete" = "no"
  }

}
###module "cluster_auto_scaler" {
# #
# # source = "../aws-eks-module/modules/cluser-autoscaler_module"
# # eks_oidc_arn = module.eks_iam.eks_oidc_arn
# # eks_oidc_url = module.eks_iam.eks_oidc_url
# # eks_name = module.eks_cluster.eks_name
# # region = data.aws_region.eks.name
# # #namespace = "fargate"
#}#

module "cluster_auto_scaler" {
 
  source = "../aws-eks-module/modules/karpenter-module"
  eks_oidc_arn = module.eks_iam.eks_oidc_arn
  eks_oidc_url = module.eks_iam.eks_oidc_url
  eks_name = module.eks_cluster.eks_name
  region = data.aws_region.eks.name
  karpenter_version = "v0.16.1"
  eks_cluster_endpoint = module.eks_cluster.endpoint
  namespace = "karpenter"
  eks_node_role = module.eks_iam.eks_node_iam_role_name
}

