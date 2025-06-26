# Local variables for reusability
locals {
  name = "kops"
  }

# Fetch existing Route53 zone
data "aws_route53_zone" "zone" {
  name         = "pmolabs.space"
  private_zone = false
}

# Create Route53 A record for kOps server
resource "aws_route53_record" "kops_dns" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "kops.pmolabs.space"
  type    = "A"
  ttl     = 300
  records = [aws_instance.kops.public_ip]
}

# VPC configuration with one public subnet
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name}-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["eu-west-1a"]
  public_subnets = ["10.0.1.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name = "${local.name}-vpc"
  }
}

# Security group for kOps EC2 instance
resource "aws_security_group" "kops-sg" {
  name        = "${local.name}-sg"
  description = "Security group for kOps EC2 instance (SSM only, no SSH)"
  vpc_id      = module.vpc.vpc_id

  # Egress rule: Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags =  {
    Name = "${local.name}-sg"
  }
}

# Get the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create EC2 instance for kOps server
resource "aws_instance" "kops" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  user_data                   = file("${path.module}/userdata.sh")
  iam_instance_profile        = aws_iam_instance_profile.kops_profile.name
  vpc_security_group_ids      = [aws_security_group.kops-sg.id]

  tags = {
    Name = "${local.name}-server"
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "kops-role" {
  name = "${local.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${local.name}-role"
  }
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "kops_profile" {
  name = "${local.name}-profile"
  role = aws_iam_role.kops-role.name
}

# IAM policy attachments
# Enable SSM access
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Full access to EC2
resource "aws_iam_role_policy_attachment" "ec2_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Full access to IAM
resource "aws_iam_role_policy_attachment" "iam_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

# Full access to S3
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Full access to Route53
resource "aws_iam_role_policy_attachment" "route53_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

# Full access to EventBridge
resource "aws_iam_role_policy_attachment" "eventbridge_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
}

# Full access to SQS
resource "aws_iam_role_policy_attachment" "sqs_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Full access to VPC
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}
