terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

provider "aws" {
  region     = "us-west-2"
  access_key = var.kad_admin_access_key
  secret_key = var.kad_admin_secret_key
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)  # Generates 10.0.0.0/24
  map_public_ip_on_launch = true
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

# Private Subnet 1 in AZ1
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
   cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)  # Generates 10.0.0.0/24
  availability_zone = "us-west-2a"  # Choose the first AZ
}

# Private Subnet 2 in AZ2
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
   cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)  # Generates 10.0.0.0/24
  availability_zone = "us-west-2b"  # Choose the second AZ
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }

}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NAT Gateway for Private Subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Route Table for Public Subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id  # Route to the Internet Gateway
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}


# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private_association_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private_association_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name" 
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws-ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

resource "aws_key_pair" "ssh-key" {
  key_name = var.key_pair_name
  public_key = file(var.path_to_key_pair)

}

# Define the IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "my_ec2_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        },
      },
    ],
  })
}

# Attach policies to the IAM Role
resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_kad_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Attach the IAM Role to the EC2 Instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "my_instance_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.latest-amazon-linux-image.id  # Amazon Linux 2 or Ubuntu
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.ssh-key.key_name
  security_groups = [aws_security_group.bastion_sg.id]
   # Associate IAM role with the EC2 instance
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
}

resource "aws_eip" "bastion_ip" {
  instance = aws_instance.bastion.id
}

output "bastion_eip" {
  value = aws_eip.bastion_ip.public_ip
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [var.my_ip]  # Only allow your VPN IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "private_instance" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_1.id
  security_groups = [aws_security_group.private_sg.id]
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]  # Only Bastion can access
  }

}

resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]  # Only Bastion can access
  }

depends_on = [aws_instance.bastion]
}


# Now, you can use data.aws_cloudwatch_log_group.eks_auth_logs.arn wherever needed


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "example-cluster"
  cluster_version = "1.29"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  vpc_id          = aws_vpc.main.id

 subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
    ]

eks_managed_node_groups = {
    example = {
      instance_type = ["t3.small"]
      max_size  = 3
      security_groups = [aws_security_group.eks_sg.id]
    }
}

# Enable specific control plane logs
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # CloudWatch Log Group Configuration
  create_cloudwatch_log_group   = true
  cloudwatch_log_group_retention_in_days = 90

  iam_role_name        = "my_ec2_role"
  iam_role_description = "IAM Role for EKS cluster created using Terraform IaC"

  enable_cluster_creator_admin_permissions = true

cluster_additional_security_group_ids = [aws_security_group.eks_sg.id]
}











