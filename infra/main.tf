# Read the VPC and subnets provisioned by Episode 2 — ep4 builds on that network
# rather than spinning up a new VPC. The "network" output was added to ep2's
# outputs.tf as part of this episode's setup.
data "terraform_remote_state" "ep2" {
  backend = "remote"
  config = {
    organization = "steve-weaver-demo-org"
    workspaces = {
      name = "ep2-dev"
    }
  }
}

# Latest Amazon Linux 2 AMI in the target region
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Minimal security group — outbound only, no inbound access needed for the demo
resource "aws_security_group" "demo_node" {
  name        = "ep4-demo-node-sg"
  description = "Demo node for Ep4 Terraform Actions"
  vpc_id      = data.terraform_remote_state.ep2.outputs.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ep4-demo-node-sg" }
}

resource "aws_instance" "demo_node" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  subnet_id     = data.terraform_remote_state.ep2.outputs.network.public_subnet_ids[0]

  vpc_security_group_ids = [aws_security_group.demo_node.id]

  tags = { Name = "ep4-demo-node" }

  # Uncomment to demonstrate lifecycle-bound action triggers (Ep4 segment 2)
  # lifecycle {
  #   action_trigger {
  #     events  = ["after_update"]
  #     actions = [action.aws_ec2_stop_instance.stop_on_alert]
  #   }
  # }
}
