# Consumed by the ops workspace via terraform_remote_state
output "instance_id" {
  description = "EC2 instance ID targeted by the stop_on_alert action"
  value       = aws_instance.demo_node.id
}

output "instance_public_ip" {
  description = "Public IP of the demo node (visible in UI during demo)"
  value       = aws_instance.demo_node.public_ip
}
