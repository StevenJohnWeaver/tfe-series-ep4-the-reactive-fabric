# Episode 4: The Reactive Fabric — Terraform Actions & Event-Driven Workflows

## Series context
Part of "Mastering Infrastructure Lifecycle Management with Terraform" — 9-episode series.
Audience: Practitioners & Enterprise Architects (intermediate/advanced). ~15 min lightboard format.

## This episode
Goal: move Terraform from deployment tool to Execution Plane by introducing Terraform Actions
as first-class Day 2 operational citizens. Demonstrate a Datadog → HCP Terraform API →
`aws_ec2_stop_instance` action flow through a dedicated operations workspace, governed by
the same Sentinel policies carried forward from Episodes 2 and 3.

## Architecture decisions

### Two-workspace pattern (infra + ops)
The EC2 instance lives in `ep4-vm-prod` (infra workspace, VCS-driven). The action lives in
`ep4-ops-vm` (ops workspace, webhook-driven). The ops workspace reads the instance ID from
the infra workspace's remote state, then targets it with the action.

**Why separate workspaces?** The ops workspace carries a tightly scoped RBAC policy: on-call
engineers have invoke rights here but not unrestricted apply rights on the infra workspace.
This is the blast-radius containment story — one signal, one targeted action, everything else
untouched.

### Builds on ep2's network, not a new VPC
`infra/main.tf` reads ep2-dev's remote state for `vpc_id` and `public_subnet_ids`. The demo
EC2 instance lives in the same VPC as the EKS cluster from Episodes 1–3. This requires the
`network` output to be present in the ep2-dev workspace (see Setup reference).

### Action: aws_ec2_stop_instance (not restart)
The available AWS native action is stop, not restart. The narrative frames this as the right
enterprise response to a health check failure: controlled stop for quarantine/inspection rather
than an immediate restart that keeps the bad process running longer.

### Same IAM role as ep2
Both ep4 workspaces reuse the same `TFC_AWS_RUN_ROLE_ARN` from ep2. No new IAM role needed.

## Status: scaffolded, not yet deployed

## Setup reference

### Prerequisites
1. **Add `network` output to ep2's `outputs.tf`** — non-destructive, just expose
   `module.network.vpc_id` and `module.network.public_subnet_ids` under an `output "network"`
   block, then apply the ep2-dev workspace. The ep4 infra workspace remote_state read depends
   on this output existing.

2. **Create two HCP Terraform workspaces** in `steve-weaver-demo-org`:
   - `ep4-vm-prod` → VCS-connected to this repo, working directory = `infra/`
   - `ep4-ops-vm` → VCS-connected to this repo, working directory = `ops/`

3. **Workspace variables (both workspaces, Environment Variables):**
   - `TFC_AWS_PROVIDER_AUTH` = `true`
   - `TFC_AWS_RUN_ROLE_ARN` = same role ARN as ep2 workspaces
   - Terraform Variables: `region`, `environment`, `default_tags` (must include `environment`
     and `owner` keys to satisfy the `require-tags` Sentinel policy)

4. **Sentinel policy set** `ep4-guardrails`:
   - Source = this repo, path = `sentinel/`
   - Scope to both `ep4-vm-prod` and `ep4-ops-vm`

5. **RBAC** — in HCP Terraform: give on-call team invoke rights on `ep4-ops-vm`; restrict
   apply rights on `ep4-vm-prod` to infra team only. This is the governance separation
   demonstrated in the 9:30–13:30 segment.

6. **Apply ep4-vm-prod** first to provision the EC2 instance and publish its `instance_id`
   output. Then apply ep4-ops-vm so it can read that output.

### Lock files
Generate on macOS and regenerate for linux_amd64 (same issue as ep2):
```
terraform -chdir=infra providers lock -platform=linux_amd64 -platform=darwin_arm64
terraform -chdir=ops providers lock -platform=linux_amd64 -platform=darwin_arm64
```

### Triggering the action (demo)
```bash
export TFE_TOKEN=<your-token>
export TFE_WORKSPACE_ID=ws-XXXXXXXX   # ep4-ops-vm workspace ID from HCP Terraform UI
./scripts/trigger-action.sh
```
The workspace ID is in HCP Terraform → ep4-ops-vm → Settings → ID.

## Known gotchas

- **Terraform version for `action {}` blocks**: `required_version = ">= 1.10.0"` is set
  as a floor but the exact minimum supporting the `action {}` HCL block should be confirmed
  against the HCP Terraform agent pool version before recording. If the workspace shows a
  version error, bump the constraint.
- **Only one action per run**: `invoke-action-addrs` accepts a list but HCP Terraform
  enforces exactly one action address per run by design. The trigger script sets one address.
- **Remote state access**: the `ep4-ops-vm` workspace must have remote state access granted
  from `ep4-vm-prod`. In HCP Terraform: ep4-vm-prod workspace → Settings → Remote State
  Sharing → share with ep4-ops-vm. Same applies for ep2-dev → ep4-vm-prod.
- **Sentinel `tags_all` guard**: ep4's `require-tags.sentinel` is inherited from ep2 and
  already guards with `after contains "tags_all"` before checking — don't remove that guard,
  `aws_security_group_rule` and similar sub-resources have no `tags_all`.
- **Sentinel `not`/`contains` precedence**: `not x contains y` parses as `(not x) contains y`
  — already parenthesized correctly in both sentinel files, don't regress.
- **Environment Variables vs Terraform Variables**: `TFC_AWS_PROVIDER_AUTH` and
  `TFC_AWS_RUN_ROLE_ARN` must be set under **Environment Variables** in the workspace, not
  Terraform Variables — easy to mis-categorize in the UI.

## Demo flow (recording guide)

### 0:00–2:00 | Hook
Lightboard: write CONTROL PLANE (left, arrows out) and EXECUTION PLANE (right, arrows in),
bridge labeled ACTIONS. Narrative: Terraform as Execution Plane, Day 2 ops as first-class
citizens.

### 2:00–5:00 | First-Class Operational Citizen
Show `infra/main.tf` — the EC2 instance. Show `ops/main.tf` — the `action {}` block
referencing the instance ID from remote state. Draw the audit trail: Apply (infra) and Action
Execution (ops) on the same line.

**Hard block trip-wire:** edit `infra/main.tf`, change `instance_type` from `"t3.micro"` to
`"p3.2xlarge"`, push — show the `allowed-instance-types` hard-mandatory block. Revert.

**Soft block trip-wire:** remove `owner` from `default_tags` workspace variable in the UI
(no commit needed), queue a plan on ep4-vm-prod — show the `require-tags` soft-mandatory
block and admin override flow. Restore the tag.

### 5:00–9:30 | Detection to Intervention
Draw the 3-step loop: Sensor (Datadog) → Decision (HCP Terraform API) → Intervention
(action). Show `scripts/trigger-action.sh` — the single `curl` POST with
`invoke-action-addrs`. Fire it live, switch to HCP Terraform UI, show the run appearing in
ep4-ops-vm with the Datadog message, show the plan targeting only the action, show the
instance stopping.

Reference the native Actions list for AWS, Azure, GCP, and AAP (covered next episode).

### 9:30–13:30 | Architecture: Dedicated Operations Workspace
Lightboard: draw infra-vm-prod (left, VCS-driven) and ops-vm-restart (right,
webhook-driven), arrow for remote state read, arrow from Datadog into ops workspace.
Narrative: RBAC separation, blast radius containment, ops workspace as a router that can
signal ServiceNow or configuration management systems.

### 13:30–15:00 | Bridge to Episode 5
Circle the Signal arrow. Write EPISODE 5: THE HYBRID HANDSHAKE. Narrative: what happens
after the signal is sent to an external system — Terraform + Ansible AAP.

Call to action: "Look at your manual Day 2 runbooks — identify one task that belongs in
your infrastructure's audit trail. Make it a First-Class Citizen."

## Ep4→Ep5 handshake
Ep5 reads its infrastructure facts from the ep2 `config_facts` output (cluster endpoint,
region, etc.), not from ep4. Ep4 is a self-contained Day 2 demo; it does not need to
publish a handshake output for Ep5.
