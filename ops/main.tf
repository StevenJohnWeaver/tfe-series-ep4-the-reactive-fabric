# Read the instance ID provisioned by the infra workspace
data "terraform_remote_state" "infra" {
  backend = "remote"
  config = {
    organization = "steve-weaver-demo-org"
    workspaces = {
      name = "ep4-vm-prod"
    }
  }
}

# Targeted stop action — invoked on-demand via the HCP Terraform Runs API.
# This workspace is the webhook target; the infra workspace is untouched.
# API payload: { "invoke-action-addrs": ["action.aws_ec2_stop_instance.stop_on_alert"] }
action "aws_ec2_stop_instance" "stop_on_alert" {
  config {
    instance_id = data.terraform_remote_state.infra.outputs.instance_id
  }
}
