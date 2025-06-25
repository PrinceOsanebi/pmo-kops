locals {
  name = "jenkins"
}

# Create a single-AZ VPC with one public subnet (no NAT, no VPN) from terraform remote module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a"]
  public_subnets  = ["10.0.1.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

    tags = {
    Name = "${local.name}-vpc"
  }
  }

# Fetch the most recent RedHat Enterprise Linux (RHEL) 9 AMI owned by RedHat
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Generate a new RSA private key for the key pair
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the generated private key locally with restricted permissions
resource "local_file" "private_key" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}

# Create an AWS key pair using the generated public key
resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.keypair.public_key_openssh
}


# Create IAM role for Jenkins server to assume  SSM role
resource "aws_iam_role" "ssm-jenkins-role" {
  name = "${local.name}-ssm-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AmazonSSMManagedInstanceCore policy to Jenkins IAM role
resource "aws_iam_role_policy_attachment" "ssm-policy" {
  role       = aws_iam_role.ssm-jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AdministratorAccess policy to Jenkins IAM role
resource "aws_iam_role_policy_attachment" "jenkins-admin-role-attachment" {
  role       = aws_iam_role.ssm-jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create instance profile for Jenkins server
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.name}-ssm-jenkins-profile"
  role = aws_iam_role.ssm-jenkins-role.name
}

# Create a security group for Jenkins server allowing inbound traffic on port 8080 and all outbound traffic
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow Jenkins traffic"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound TCP traffic on port 8080 from anywhere (Jenkins default port)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

# Launch Jenkins EC2 instance in public subnet with key, IAM profile, and user data
resource "aws_instance" "jenkins-server" {
  ami                         = data.aws_ami.redhat.id # Latest RedHat AMI in region
  instance_type               = "t2.large"
  key_name                    = aws_key_pair.public_key.key_name
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name

  # Configure root volume: 20 GB, gp3 type, encrypted
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  # User data script for Jenkins setup with region variable
  user_data = templatefile("./jenkins_userdata.sh", {
    region = var.region,
    RELEASE_VERSION = ""
  })

    # Require IMDSv2 tokens for metadata service security
  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Get the public Route53 hosted zone for the domain
data "aws_route53_zone" "acp_zone" {
  name         = "pmolabs.space"
  private_zone = false
}

# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "acm_cert" {
  domain_name               = "pmolabs.space"
  subject_alternative_names = ["jenkins.pmolabs.space"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm-cert"
  }
}

# Create DNS records in Route53 for ACM certificate domain validation
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # Set DNS record values required for ACM certificate validation
  zone_id         = data.aws_route53_zone.acp_zone.zone_id
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]

  depends_on = [aws_acm_certificate.acm_cert]
}

# Validate the ACM certificate after the DNS records have been created
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.acm_cert.arn

  # Use the fully qualified domain names of the DNS records for validation
  validation_record_fqdns = [
    for record in aws_route53_record.acm_validation_record :
    record.fqdn
  ]

  # Ensure DNS records are created before attempting validation
  depends_on = [
    aws_acm_certificate.acm_cert,
    aws_route53_record.acm_validation_record
  ]
}

# Create security group for Jenkins ELB allowing HTTP and HTTPS traffic
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Allow HTTP/HTTPS traffic to Jenkins ELB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    description = "Allow inbound HTTP traffic on port 80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    description = "Allow inbound HTTPS traffic on port 443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    description = "Allow all outbound traffic"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-jenkins-elb-sg"
  }
}

# Fetch availability zones for the region (used for ELB placement)
data "aws_availability_zones" "available" {}

# Create classic ELB for Jenkins with HTTPS listener on port 443 forwarding to Jenkins instance port 8080
resource "aws_elb" "elb_jenkins" {
  name               = "elb-jenkins"
  security_groups    = [aws_security_group.jenkins_elb_sg.id]
  subnets            = [module.vpc.public_subnets[0]]

  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8080"
  }

  instances                   = [aws_instance.jenkins-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create Route 53 record for jenkins server
resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.acp_zone.id
  name    = "jenkins.pmolabs.space"
  type    = "A"
  alias {
    name                   = aws_elb.elb_jenkins.dns_name
    zone_id                = aws_elb.elb_jenkins.zone_id
    evaluate_target_health = true
  }
}