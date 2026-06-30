# Episode 4 Demo Talk Track
## "The Reactive Fabric — Terraform Actions & Event-Driven Workflows"
**Format:** Lightboard / Demo | **Target Duration:** ~15 minutes

> **Before you record:**
> - `ep4-vm-prod` applied cleanly — EC2 instance running and visible in the AWS Console
> - `ep4-ops-vm` applied cleanly — action definition registered
> - Remote state sharing enabled: ep2-dev → ep4-vm-prod → ep4-ops-vm
> - Sentinel policy set `ep4-guardrails` scoped to both workspaces and passing
> - `TFE_TOKEN` and `TFE_WORKSPACE_ID` exported in your terminal for `trigger-action.sh`
> - EC2 instance in **running** state — check the AWS Console before starting
> - Have HCP Terraform (ep4-ops-vm runs tab) and the AWS Console open in separate windows
> - Rehearse the `trigger-action.sh` → run appears → instance stops flow at least once
>   so you know the latency between firing the script and the run appearing in the UI

---

## 0:00 – 2:00 | The Hook: The Day 2 Blind Spot

**On screen:** Lightboard. Write **CONTROL PLANE** on the left with arrows pointing outward
labeled "Instructions". Write **EXECUTION PLANE** on the right with arrows pointing inward
labeled "Interventions". Draw a bridge between them labeled **ACTIONS**.

**Say:**
> "In our first three episodes, we built a perfectly governed Control Plane. It sends
> instructions, waits for confirmation, and maintains a ledger of state. But in a high-scale
> enterprise, knowing what *should* exist isn't enough. You need the ability to intervene
> when reality breaks.
>
> Today, we're talking about the evolution of Terraform from a deployment tool to an
> **Execution Plane**. We're introducing **Terraform Actions** — not as mere scripts, but as
> **First-Class Operational Citizens**. Governed capabilities that let you manage
> infrastructure *behavior* with the same auditability we've already established for
> infrastructure *code*.
>
> Terraform Actions, introduced in 2025, let you define operational tasks in HCL right
> alongside your infrastructure. Things like stopping a VM, rotating a secret, clearing
> a cache, triggering a backup — any task you'd normally do manually in a cloud console
> or via a shell script. They're defined in code, tied to specific resources, executed
> through the Terraform CLI or the HCP Terraform UI — and they're audited in the same
> trail as your applies. Governed. Subject to RBAC and policy. Versioned in your VCS."

---

## 2:00 – 5:00 | The First-Class Operational Citizen

**On screen:** Show `ops/main.tf` — the `action` block. Sketch the equivalent HCL on the
lightboard alongside it:

```hcl
action "aws_ec2_stop_instance" "stop_on_alert" {
  config {
    instance_id = data.terraform_remote_state.infra.outputs.instance_id
  }
}
```

Draw a simple timeline below: mark **Apply** (ep4-vm-prod) and **Action Execution**
(ep4-ops-vm) on the same line, labeled **THE AUDIT TRAIL**.

**Say:**
> "What does it mean to be a first-class citizen? It means the operation is defined in HCL,
> tied directly to the resource identity, and invoked through the same toolchain as your
> deployments. The `action` block follows the same pattern as a `resource` block — provider
> and action type, then a name, then a config block with action-specific parameters.
>
> Notice what this action references: `data.terraform_remote_state.infra.outputs.instance_id`.
> No hardcoded IDs. The ops workspace knows which instance to target because it reads the
> state of the provisioning workspace. That's the handshake — remote state as a living
> contract between workspaces.
>
> In the past, if this VM was hung, you'd leave Terraform entirely, log into a cloud console,
> and click Stop. The stop happened — but Terraform had no record of it. By framing this as
> an action, we keep the operational history inside the same audit trail as the infrastructure
> code. We aren't just auditing *what we built*; we're auditing *how we operated it*."

**Say:**
> "And because actions are defined in code, we can apply the same Sentinel policies and RBAC
> controls to an action invocation that we apply to a deployment. Let me show you that
> governance in action."

---

### Trip-wire 1: Hard Block (Sentinel — `allowed-instance-types`)

**On screen:** Edit `infra/main.tf`. Change `instance_type = "t3.micro"` to
`instance_type = "p3.2xlarge"`. Push. Switch to HCP Terraform — ep4-vm-prod.

**Say:**
> "Here I'm trying to upgrade the demo node to a p3 GPU instance. Let's see what happens."

*[Show the hard-mandatory policy block in the HCP Terraform UI]*

> "Blocked. `allowed-instance-types` is hard-mandatory — no override, no exception. The
> same policy that governs our EKS nodes in Episodes 2 and 3 governs this EC2 instance.
> The governance layer doesn't know or care whether it's reviewing an EKS node group or
> a standalone instance — it evaluates the plan."

**On screen:** Revert `infra/main.tf` to `"t3.micro"`. Push.

---

### Trip-wire 2: Soft Block + Override (Sentinel — `require-tags`)

**On screen:** In the HCP Terraform UI — ep4-vm-prod workspace → Variables. Remove `owner`
from `default_tags` (no commit needed — workspace variable change). Queue a plan.

**Say:**
> "Now I'm removing the `owner` tag. No code change — just a workspace variable edit.
> Let's see if governance catches it."

*[Show the soft-mandatory policy block]*

> "`require-tags` fires. Soft-mandatory — which means a workspace admin can override it
> with a justification. That override is logged. It becomes part of the audit trail, same
> as the action itself."

*[Demonstrate the override-and-approve flow. Then restore the `owner` tag in the variable.]*

---

## 5:00 – 9:30 | The Workflow: Detection to Intervention

**On screen:** Lightboard. Draw the 3-step loop:
1. **SENSOR** — Datadog / external APM
2. **DECISION** — HCP Terraform Runs API
3. **INTERVENTION** — the action

**Say:**
> "Let's walk through the architectural flow. In Episode 3, Terraform detected *architectural*
> drift — resources diverging from state. But application-level failures need a different
> sensor. A VM that's running but unhealthy. A process that's hung. A health check that's
> been failing for five minutes.
>
> Step one: the sensor. An external monitor — in our demo, Datadog — detects a failed
> health check and fires a webhook. A single HTTP POST directly into the HCP Terraform
> Runs API.
>
> Step two: the decision. Instead of a manual scramble, the API triggers an authorized action.
> The key is in the payload."

**On screen:** Show `scripts/trigger-action.sh` — highlight the `invoke-action-addrs` line.

> "This attribute — `invoke-action-addrs` — is what makes the intervention surgical. It tells
> HCP Terraform: run *this specific action*, nothing else. One signal. One targeted
> intervention. Note that only one action is allowed per run, by design — a guardrail that
> prevents a single webhook from triggering a cascade of unreviewed operations.
>
> Step three: the intervention."

**On screen — live demo:** Start screen recording. Fire `./scripts/trigger-action.sh` in
the terminal. Switch immediately to HCP Terraform → ep4-ops-vm → Runs.

> "I'm firing the script now. This is exactly the call Datadog would make."

*[Show the run appearing in ep4-ops-vm with the message "Datadog: ep4-demo-node health
check failed — stopping instance"]*

> "The run appears. The workspace enters a plan state — but because an action address was
> specified, Terraform focuses only on that action. Everything else in the workspace is
> untouched. And notice — no one had to click Apply. The trigger payload set `auto-apply:
> true`, so the moment the plan finishes, it executes. That's the point: a 2am page doesn't
> need a human in the loop to greenlight a narrowly-scoped, policy-governed action. Watch
> the run log."

*[Show the action executing — instance stopping]*

> "The instance is stopping. Let's confirm in the AWS Console."

*[Switch to AWS Console → EC2 → show the instance transitioning to stopped]*

> "Stopped."

**On screen:** Switch to HCP Terraform → ep4-ops-vm → **Actions** tab → select
`aws_ec2_stop_instance.stop_on_alert`. Point to the invocation history row.

> "And here's the audit trail HCP Terraform gives us natively — the Actions panel. Status:
> Successful. Source: API. Invoked by the token that fired it. Timestamped. This is the
> same governance surface as a deployment, applied to an operation. The remediation didn't
> happen in a Slack thread. It happened here, with full provenance."

*[Optional: click **Invoke** on this panel to show the action can also be triggered
manually from the UI, not just the API — same governed path either way.]*

**On screen:** Show the native AWS action list (reference slide or lightboard):
- EC2: stop instance, Lambda invoke, CloudFront invalidation, DynamoDB backup, SNS publish
- Azure: VM power actions, cache purge, database flush
- GCP: Compute instance operations, Cloud Run restart
- AAP: Ansible job launch *(covered in Episode 5)*

> "These are the native provider actions available today. And if your system isn't on this
> list, you can build custom actions to integrate with any API. The pattern is the same —
> define it in HCL, invoke it through the same toolchain."

---

## 9:30 – 13:30 | The Architecture: The Dedicated Operations Workspace

**On screen:** Lightboard. Draw TWO workspaces side by side:
- Left: **ep4-vm-prod** (VCS-driven, owns the resource)
- Right: **ep4-ops-vm** (webhook-driven, owns the action)

Draw an arrow from **ep4-ops-vm** reading **remote state** from **ep4-vm-prod**.
Draw an arrow from **Datadog** into **ep4-ops-vm**.

**Say:**
> "A natural question: should the action live in the same workspace as the resource? The
> answer is — it can. But for production patterns, separating them is the right call.
>
> Here's why. The ops workspace has a fundamentally different access profile. Your on-call
> engineer has invoke rights here — they can trigger a stop action at 2am without waking
> anyone up. But they do *not* have unrestricted apply rights on the infrastructure workspace.
> Your senior platform engineer holds those. The blast radius is contained by design.
>
> The ops workspace reads the instance ID from the provisioning workspace's remote state.
> It doesn't duplicate the resource definition — it just knows where to find the target.
> When the instance is replaced or moved, the remote state updates. The ops workspace follows
> automatically, with no manual ID management.
>
> And this is also true for the handoff pattern. The action doesn't have to do the fix
> itself. It acts as a router, signaling external systems. A stop action can simultaneously
> update a ServiceNow incident and signal your configuration management suite to re-verify
> the node when it comes back up. We've turned our infrastructure into a reactive nervous
> system that knows how to call for help."

**On screen:** Lightboard — draw the signal arrow from the ops workspace branching out to
ServiceNow and a config management icon.

> "Because the truth of the enterprise is this: if your remediation happens in a Slack
> thread, it didn't happen."

---

## 13:30 – 15:00 | Summary & The Bridge to Episode 5

**On screen:** Lightboard — circle the **signal arrow** from the ops workspace. Write
**EPISODE 5: THE HYBRID HANDSHAKE**.

**Say:**
> "Today we moved Terraform into the Execution Plane. We stopped treating Day 2 operations
> as a separate landscape and brought them into our single source of truth. The mechanism
> is concrete: an `action {}` block in HCL, and an `invoke-action-addrs` attribute in the
> Runs API. One signal. One targeted action. Full audit trail.
>
> But what happens *after* that signal is sent to an external system?
>
> In the next episode, we're going to look at the most common operational handshake in the
> enterprise: **Terraform and Ansible Automation Platform**. How do you coordinate the
> infrastructure provisioner with the configuration management platform to build a truly
> self-healing estate? I'll see you in Episode 5."

**Call to action:**
> "Look at your manual Day 2 runbooks — and identify one task that belongs in your
> infrastructure's audit trail. Make it a First-Class Citizen."

---

## Timing Reference

| Segment | Duration |
|---|---|
| The Hook | 2:00 |
| First-Class Citizen (code walkthrough + two trip-wires) | 3:00 |
| Detection to Intervention (live webhook demo) | 4:30 |
| Dedicated Operations Workspace | 4:00 |
| Summary & Bridge | 1:30 |
| **Total** | **~15:00** |

---

## Recording Tips

- **Start the instance before recording.** The EC2 instance must be in a running state for
  the stop action to be meaningful on camera. Check the AWS Console before you hit record.
- **Pre-fire the script off-camera first.** Confirm the action runs end-to-end on the day
  of recording. Then start the instance again and fire it live.
- **Tab order matters.** Keep terminal, HCP Terraform (ep4-ops-vm runs), and AWS Console
  (EC2 instances) open in that order — the live sequence moves terminal → HCP TF → AWS
  Console and the cut should feel smooth.
- **The `invoke-action-addrs` attribute is the moment.** Pause on it. The audience needs
  to understand that this is what makes the run surgical — it's not a full plan/apply.
- **The audit trail close-up is the payoff.** After the instance stops, linger on the
  Actions tab invocation history in ep4-ops-vm showing the Datadog-triggered run tied to
  the action. That juxtaposition — external alert → governed action → provenance — is the
  core argument of the episode.
- **Auto-apply is a talking point, not a silent default.** Say out loud that the run
  applies without a manual click, and why that's safe here: Sentinel policy + RBAC scoping
  on who can call the API stand in for the human review step. Don't let it look like an
  oversight.
- **Trip-wire timing:** hard block and soft block are in the 2:00–5:00 segment. Build about
  90 seconds for each — they're fast but worth showing cleanly, not rushed.
- **Bridge framing:** the AAP action (`ansible-automation-platform_job_launch`) is the
  natural Ep5 teaser. If it feels right, show it listed in the native actions UI as a
  "coming in Ep5" moment rather than just mentioning it verbally.
