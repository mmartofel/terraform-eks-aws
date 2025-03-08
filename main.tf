provider "aws" {
  region = "us-east-1" # Specify your desired AWS region
}

data "aws_availability_zones" "available" {}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "zenek"
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.cluster_name}_vpc"
  }
}

resource "aws_subnet" "eks_subnet" {
  count                   = 2
  vpc_id                 = aws_vpc.eks_vpc.id
  cidr_block             = "10.0.${count.index}.0/24"
  availability_zone      = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.cluster_name}_subnet_${count.index}"
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn
  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
  }
}

resource "aws_iam_role" "eks_role" {
  name = "${var.cluster_name}_role"

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
  node_group_name = "${var.cluster_name}_node_group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}_node_role"

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

# NETWORKING SETUP

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "${var.cluster_name}_igw"
  }
}

# Create a NAT Gateway
resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id    = aws_subnet.eks_subnet[0].id  # Use a public subnet for the NAT Gateway

  tags = {
    Name = "${var.cluster_name}_nat"
  }
}

# Update the route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}_public_rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.eks_subnet[0].id
  route_table_id = aws_route_table.public.id
}

# Update the route table for the private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.cluster_name}_private_rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.eks_subnet[1].id
  route_table_id = aws_route_table.private.id
}