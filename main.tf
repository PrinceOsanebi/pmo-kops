# Use existing hosted zone
data "aws_route53_zone" "zone" {
  name         = "pmolabs.space"
  private_zone = false
}
# Create a DNS A record pointing to the KOps server's IP
resource "aws_route53_record" "kops_dns" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "kops.pmolabs.space"
  type    = "A"
  ttl     = 300
  records = [aws_instance.kops.public_ip]

}

locals {
  name = "kops"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name}-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["eu-west-1a"]
  public_subnets = ["10.0.1.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name = local.name
  }
}

# Creating security group for kOps server
resource "aws_security_group" "kops-sg" {
  name        = "${local.name}-sg"
  description = "Allow inbound traffic from vpc and all outbound traffic"
  vpc_id      = module.vpc.vpc_id

  # Egress rule: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound to anywhere
  }

  tags = {
    Name = "${local.name}-sg"
  }
}

# use latest ubuntu image
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

# create ubuntu server 
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

#SSM policy 
# create an IAM instance role
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

# kops IAM profile
resource "aws_iam_instance_profile" "kops_profile" {
  name = "${local.name}-profile"
  role = aws_iam_role.kops-role.name
}

# SSM permission
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ec2 permission
resource "aws_iam_role_policy_attachment" "ec2_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# iam permission
resource "aws_iam_role_policy_attachment" "iam_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

# S3 permission
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# route53 permission
resource "aws_iam_role_policy_attachment" "route53_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

# eventbridge permission
resource "aws_iam_role_policy_attachment" "evenbridge_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
}

# Sqs permission
resource "aws_iam_role_policy_attachment" "sqs_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# vpc permission
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.kops-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}