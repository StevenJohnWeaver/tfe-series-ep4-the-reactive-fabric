# Episode 4: The Reactive Fabric — Terraform Actions & Event-Driven Workflows

This repo demonstrates **Terraform Actions** as first-class Day 2 operational citizens —
governed, audited, and versioned alongside your infrastructure code.

The demo shows a Datadog health-check alert triggering a targeted EC2 stop action via the
HCP Terraform Runs API, through a dedicated operations workspace with scoped RBAC — without
touching the infrastructure workspace at all.

> **Why this matters:** In most estates, Day 2 operations live in Slack threads and cloud
> console clicks. Terraform Actions bring them into the same audit trail as your deployments.
> One signal. One targeted action. Full provenance.

---

## What this episode demonstrates

- **`action {}` blocks in HCL** — Day 2 operations defined as code, bound to a specific resource
- **`aws_ec2_stop_instance` native action** — invoked on-demand via the Runs API, not a full plan/apply cycle
- **Dedicated operations workspace** — tightly scoped RBAC; on-call invokes actions here without apply rights on the infra workspace
- **Remote state as the handshake** — the ops workspace reads the instance ID from the infra workspace's state; no hardcoded IDs
- **Sentinel governance carried forward** — the same `allowed-instance-types` and `require-tags` policies from Episodes 2–3 govern both workspaces
- **Event-driven trigger** — `scripts/trigger-action.sh` simulates a Datadog webhook: a single `curl` POST to the HCP Terraform Runs API with `invoke-action-addrs`

---

## Architecture

```
Datadog alert
     │
     ▼ (HTTP POST — invoke-action-addrs)
┌─────────────────────────┐        remote state read
│   ep4-ops-vm workspace  │ ◄────────────────────────── ep4-vm-prod workspace
│   (webhook-driven)      │                              (VCS-driven)
│                         │                              │
│  action "aws_ec2_       │                              │  aws_instance.demo_node
│    stop_instance"       │                              │  (in ep2-dev VPC)
│    "stop_on_alert" {}   │                              │
└─────────────────────────┘                              │
     │                                                   ▼
     └──── stops ─────────────────────────────────► EC2 instance
```

The EC2 instance lives in **ep2-dev's VPC** — no new VPC, no duplicate network. The infra
workspace reads ep2-dev's remote state for `vpc_id` and `public_subnet_ids`, extending the
governed estate that Episodes 1–3 built.

---

## Structure

```
.
├── CLAUDE.md                         # Architecture decisions, gotchas, recording guide
├── infra/                            # ep4-vm-prod workspace
│   ├── main.tf                       # EC2 instance + SG, reads ep2-dev remote state
│   ├── providers.tf                  # AWS dynamic credentials
│   ├── variables.tf
│   └── outputs.tf                    # instance_id consumed by ops workspace
├── ops/                              # ep4-ops-vm workspace
│   ├── main.tf                       # remote state read + action definition
│   ├── providers.tf
│   └── variables.tf
├── sentinel/                         # ep4-guardrails policy set
│   ├── sentinel.hcl
│   ├── allowed-instance-types.sentinel
│   └── require-tags.sentinel
├── scripts/
│   └── trigger-action.sh             # simulates Datadog webhook to Runs API
└── docs/
    └── demo-talk-track.md            # full timestamped recording script
```

---

## Prerequisites

- HCP Terraform org (`steve-weaver-demo-org`) with Episodes 2–3 workspaces applied and healthy
- ep2-dev workspace applied with the `network` output published (added in this episode's ep2 commit)
- AWS account with the same IAM role used by ep2 workspaces
- Terraform CLI ≥ 1.10.0 (or use the version from `.terraform-version`)

---

## Setup

### 1. Create two HCP Terraform workspaces

| Workspace | Working directory | VCS trigger |
|---|---|---|
| `ep4-vm-prod` | `infra/` | Push to `main` |
| `ep4-ops-vm` | `ops/` | None (webhook-driven) |

Both connect to this repo. Set the **Terraform Working Directory** per the table above.

### 2. Configure AWS dynamic credentials (both workspaces, Environment Variables)

| Variable | Value |
|---|---|
| `TFC_AWS_PROVIDER_AUTH` | `true` |
| `TFC_AWS_RUN_ROLE_ARN` | Same role ARN as ep2 workspaces |

The existing IAM trust policy from ep2 already covers `workspace:ep2-*`. Add a second
condition to also trust `ep4-*`:

```json
"StringLike": {
  "app.terraform.io:sub": "organization:<org>:project:*:workspace:ep2-*:run_phase:*"
}
```

Change the glob to cover both episode prefixes, or add a second trust statement:

```json
"StringLike": {
  "app.terraform.io:sub": "organization:<org>:project:*:workspace:ep4-*:run_phase:*"
}
```

### 3. Set Terraform variables (both workspaces)

| Variable | ep4-vm-prod | ep4-ops-vm |
|---|---|---|
| `region` | `us-east-1` | `us-east-1` |
| `environment` | `dev` | _(not needed)_ |
| `default_tags` | `{environment="dev", owner="platform"}` | `{environment="dev", owner="platform"}` |

> `default_tags` must include both `environment` and `owner` to satisfy the `require-tags`
> Sentinel policy. Set as an HCL map Terraform variable (not an environment variable).

### 4. Enable remote state sharing

In HCP Terraform — each workspace must grant access to the one that reads its state:

- **ep2-dev** → Settings → Remote State Sharing → share with `ep4-vm-prod`
- **ep4-vm-prod** → Settings → Remote State Sharing → share with `ep4-ops-vm`

### 5. Attach the Sentinel policy set

1. HCP Terraform → **Policies** → **Policy Sets** → **Create Policy Set**
2. Source: this repo, **Policies path**: `sentinel/`
3. Scope: both `ep4-vm-prod` and `ep4-ops-vm`

### 6. Generate lock files

```bash
terraform -chdir=infra providers lock -platform=linux_amd64 -platform=darwin_arm64
terraform -chdir=ops providers lock -platform=linux_amd64 -platform=darwin_arm64
```

Commit the resulting `.terraform.lock.hcl` files before connecting workspaces to VCS.

### 7. Apply in order

1. Apply **ep4-vm-prod** — provisions the EC2 instance and publishes `instance_id` to state
2. Apply **ep4-ops-vm** — reads remote state and registers the action definition

### 8. Test the action trigger

```bash
export TFE_TOKEN=<your-token>
export TFE_WORKSPACE_ID=ws-XXXXXXXX   # ep4-ops-vm workspace ID: Settings → ID
./scripts/trigger-action.sh
```

---

## Demo Sequence (Recording Guide)

Full talk track with timestamps: [`docs/demo-talk-track.md`](docs/demo-talk-track.md)

| Segment | What you show |
|---|---|
| **Hook (0:00–2:00)** | Lightboard: Control Plane vs Execution Plane, bridge labeled ACTIONS |
| **First-Class Citizen (2:00–5:00)** | `infra/main.tf` instance, `ops/main.tf` action block, hard/soft Sentinel trip-wires |
| **Detection to Intervention (5:00–9:30)** | Live: `trigger-action.sh` → run appears in ep4-ops-vm → instance stops |
| **Ops Workspace Architecture (9:30–13:30)** | Lightboard: two-workspace diagram, RBAC scoping, blast-radius story |
| **Bridge to Ep5 (13:30–15:00)** | Write EPISODE 5: THE HYBRID HANDSHAKE |

---

## Notes

- **One action per run**: `invoke-action-addrs` accepts a list but HCP Terraform enforces exactly one action address per run by design.
- **Remote state access must be explicitly granted** — the `terraform_remote_state` data source will error at plan time if sharing is not enabled in both source workspaces.
- **IAM trust policy**: both ep4 workspaces use the same role as ep2. Ensure the trust policy's `sub` glob covers `ep4-*` as well as `ep2-*`.
- **Ep5 handshake**: Episode 5 reads its infrastructure facts from ep2's `config_facts` output (cluster endpoint, region), not from ep4. Ep4 is self-contained.
