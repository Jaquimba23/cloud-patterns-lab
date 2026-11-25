output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "private_ip" {
  value = aws_instance.private.private_ip
}
