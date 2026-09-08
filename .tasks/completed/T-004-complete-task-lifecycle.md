---
id: T-004
name: "Complete a full task lifecycle for 055-agentic-fleet-cockpit"
description: >
  Create a new task for real work on 055-agentic-fleet-cockpit, complete it, and verify
  the full
  lifecycle works: create → start → work → complete → episodic generation.
status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [onboarding]
components: []
related_tasks: []
created: 2026-09-08T18:03:51Z
last_update: 2026-09-08T19:20:00Z
date_finished: 2026-09-08T19:20:00Z
bvp_scores_proposed:
  - ts: '2026-09-08T19:19:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-004: Complete a full task lifecycle for 055-agentic-fleet-cockpit

## Context

Create a genuine task for 055-agentic-fleet-cockpit (not busywork), complete it, and verify the framework captures it correctly. This validates: task creation, status transitions, acceptance criteria gating, episodic memory generation.

## For the Operator

**What is happening:** the agent runs one real task all the way round the loop — create,
work, complete — on 055-agentic-fleet-cockpit, so the machinery has been exercised once before it
matters.

**Why it matters to you:** completion is not the agent declaring itself finished. Two gates
run mechanically first. **P-010** refuses to close a task with unticked agent acceptance
criteria. **P-011** executes the shell commands the agent wrote in the task's
`## Verification` block and refuses if any of them fails. Neither can be argued with — they
run commands and read exit codes.

Then an **episodic summary** lands in `.context/episodic/`. That is the project's memory:
what was done, what was decided, what broke. Later sessions read it, which is how the
framework stops relearning the same lesson every few weeks.

**What you can do meanwhile:** watch it in Watchtower. Seeing a task move through its states
teaches the model faster than reading about it. This is also your first look at the agent
doing real work under governance rather than onboarding chores — worth judging.

**Go deeper:** `fw corpus explain aef-task-lifecycle` — including the refusal loop when a
gate says no.

## Acceptance Criteria

### Agent
- [x] Create a new task: `fw work-on "description" --type build` — T-007
- [x] Complete the task with real work (small feature, fix, or improvement) — scripts/smoke.sh, 9-check read-only post-deploy smoke test
- [x] Set status to work-completed: `fw task update T-XXX --status work-completed` — T-007 passed P-010/P-011 gates
- [x] Episodic summary generated in `.context/episodic/` — T-007.yaml

## Verification

# At least one completed task exists
test "$(ls .tasks/completed/T-*.md 2>/dev/null | wc -l)" -ge "1"
# At least one episodic summary exists
test "$(ls .context/episodic/T-*.yaml 2>/dev/null | wc -l)" -ge "1"

## Updates

### 2026-09-08T20:35:00Z — lifecycle-complete [agent]
- **Action:** T-007 ran the full loop: fw work-on → real work (scripts/smoke.sh + README row) → governed commit → work-completed through P-010/P-011 → episodic T-007.yaml generated.

### 2026-09-08T19:19:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0c964e8e
- **Timestamp:** 2026-09-08T19:20:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#2 (Agent)** — Complete the task with real work (small feature, fix, or improvement) — scripts/smoke.sh, 9-check read-only post-deploy smoke test
  - **AC-verify-mismatch** (narrow, heuristic) — `path=scripts/smoke.sh in: Complete the task with real work (small feature, fix, or improvement) — scripts/smoke.sh, 9-check read-only post-deploy smoke test`

### 2026-09-08T19:20:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
