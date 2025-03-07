provider "aws" {
  region = "us-east-1"           # Specify your desired AWS region
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks_vpc"
  }
}

resource "aws_subnet" "eks_subnet" {
  count                  = 2
  vpc_id                 = aws_vpc.eks_vpc.id
  cidr_block             = "10.0.${count.index}.0/24"
  availability_zone      = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "eks_subnet_${count.index}"
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn
  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
  }
}

resource "aws_iam_role" "eks_role" {
  name = "eks_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}