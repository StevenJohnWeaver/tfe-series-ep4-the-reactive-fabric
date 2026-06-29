#!/usr/bin/env bash
# trigger-action.sh — simulates a Datadog webhook firing into the HCP Terraform Runs API.
#
# Usage:
#   TFE_TOKEN=<your-token> TFE_WORKSPACE_ID=ws-XXXXXXXX ./scripts/trigger-action.sh
#
# The TFE_TOKEN must have permission to create runs in the ops workspace.
# Find the workspace ID in HCP Terraform: Workspace → Settings → ID.

set -euo pipefail

: "${TFE_TOKEN:?Set TFE_TOKEN to an HCP Terraform API token}"
: "${TFE_WORKSPACE_ID:?Set TFE_WORKSPACE_ID to the ep4-ops-vm workspace ID (ws-...)}"

TFE_HOST="${TFE_HOST:-app.terraform.io}"

curl -sS \
  --header "Authorization: Bearer ${TFE_TOKEN}" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @- \
  "https://${TFE_HOST}/api/v2/runs" <<EOF
{
  "data": {
    "type": "runs",
    "attributes": {
      "message": "Datadog: ep4-demo-node health check failed — stopping instance",
      "invoke-action-addrs": ["action.aws_ec2_stop_instance.stop_on_alert"]
    },
    "relationships": {
      "workspace": {
        "data": { "type": "workspaces", "id": "${TFE_WORKSPACE_ID}" }
      }
    }
  }
}
EOF

echo ""
echo "Run triggered. Check https://${TFE_HOST}/app/steve-weaver-demo-org/workspaces/ep4-ops-vm/runs"
