---
id: T-006
name: "Record first project learning for 055-agentic-fleet-cockpit"
description: >
  Capture something learned during onboarding as the first project-specific learning.
  This validates the knowledge pipeline: learning → pattern → practice graduation.
status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [onboarding]
components: []
related_tasks: []
created: 2026-09-08T18:03:51Z
last_update: 2026-09-08T19:20:53Z
date_finished: 2026-09-08T19:20:53Z
bvp_scores_proposed:
  - ts: '2026-09-08T19:20:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-006: Record first project learning for 055-agentic-fleet-cockpit

## Context

Capture something learned during setup (a gotcha, a pattern, a shortcut) as a project-specific learning. This seeds the knowledge pipeline and proves the capture mechanism works.

## For the Operator

**What is happening:** the last step of the prologue. The agent records one thing it
actually learned during T-001 through T-005 as a **learning** — a durable note that later
sessions read.

**Why it matters to you:** this is the framework's first directive, antifragility, made
concrete. A failure or a surprise is supposed to leave the project stronger than it found
it, and that only works if the lesson outlives the session that learned it. Learnings are
surfaced back at task creation, so the next agent gets told before it repeats you.

Worth checking what it wrote. A learning like *"the framework has hooks"* is noise; a
learning like *"`fw audit` exits 1 for warnings, so `test $? -le 1` is the right check"* is
the kind that saves someone an hour. You are a better judge of that than it is.

**After this task closes, the prologue is over.** The gate holding the agent to onboarding
work lifts, and it starts on whatever you actually came here to build. That is the moment
this curriculum exists for: you should now have enough of the model to follow along,
disagree, and redirect.

**Go deeper:** `fw corpus explain aef-audit-cron` — how the framework keeps checking itself
without being asked. And Watchtower `/designer` for every map at once.

## Acceptance Criteria

### Agent
- [x] Identify something learned during T-001 through T-005
- [x] Record it: `fw context add-learning "description" --task T-006` — PL-001 (P-011 Updates-fence gotcha), PL-002 (bleeding-edge hook-template gap)
- [x] Verify it appears in `.context/project/learnings.yaml`

## Verification

# At least one project-specific learning exists
python3 -c "import yaml; d=yaml.safe_load(open('.context/project/learnings.yaml')); assert len(d.get('learnings',[])) >= 1, 'No learnings found'"

## Updates

### 2026-09-08T19:20:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-08T21:25:00Z — learnings-recorded [agent]
- **Action:** PL-001 and PL-002 recorded via fw context add-learning; verified present in .context/project/learnings.yaml.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-deaad071
- **Timestamp:** 2026-09-08T19:20:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-08T19:20:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
