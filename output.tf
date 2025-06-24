output "instance_public_ip" {
  value = aws_instance.kops.public_ip
}