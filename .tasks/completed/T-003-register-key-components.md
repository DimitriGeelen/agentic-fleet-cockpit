---
id: T-003
name: "Register key components of 055-agentic-fleet-cockpit in fabric"
description: >
  Use fw fabric register to map the most important source files and their dependencies.
  This creates the structural topology map for impact analysis and onboarding.
status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [onboarding]
components: []
related_tasks: []
created: 2026-09-08T18:03:51Z
last_update: 2026-09-08T19:18:53Z
date_finished: 2026-09-08T19:18:53Z
bvp_scores_proposed:
  - ts: '2026-09-08T19:17:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-003: Register key components of 055-agentic-fleet-cockpit in fabric

## Context

The Component Fabric (`.fabric/`) maps source files and their dependencies. Register the 5-10 most important files so `fw fabric blast-radius` and `fw fabric deps` work for 055-agentic-fleet-cockpit.

## For the Operator

**What is happening:** the agent picks 5-10 files that actually matter in 055-agentic-fleet-cockpit
— entry points, core modules, config — and registers each one in the **component fabric**.

**Why it matters to you:** the fabric is a map of what depends on what. Once it exists, the
agent can answer *what breaks if I change this file* before changing it, rather than
finding out afterwards. `fw fabric blast-radius` is the question it answers, and it is the
difference between a confident edit and a hopeful one.

This step only exists for projects that already have code — a greenfield project builds its
fabric as it builds its files. Which files get registered is a judgement call the agent is
making about *your* codebase, so it is worth a glance.

**What you can do meanwhile:** look at the list it chose. If it missed the module everything
actually routes through, tell it — the map is only as good as its coverage, and you know
this codebase better than it does right now.

**Go deeper:** Watchtower `/fabric` — the same map, clickable, with the dependency graph
rendered.

## Acceptance Criteria

### Agent
- [x] Identify 5-10 key source files (entry points, core modules, config) — 8 registered
- [x] Register each with `fw fabric register <path>` — cards enriched with purpose + 18 dependency edges
- [x] Run `fw fabric overview` — shows registered components (3 subsystems: cockpit, fleet, deploy)
- [x] Run `fw fabric drift` — no critical drift (unregistered 0, orphaned 0, stale 0)

## Verification

# Fabric has registered components
test -d .fabric/components
test "$(ls .fabric/components/*.yaml 2>/dev/null | wc -l)" -ge "3"

## Updates

### 2026-09-08T19:17:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work


### 2026-09-08T20:25:00Z — fabric-registered [agent]
- **Action:** Registered cockpit-server.py, index.html, fleet.json, agentic-fleet-cockpit.service, scripts/{claude-fleet-start.sh,claude-fleet-attach.sh,cs,install.sh}; wrote .fabric/subsystems.yaml (cockpit/fleet/deploy). Overview + deps + drift all verified.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19384475
- **Timestamp:** 2026-09-08T19:18:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-08T19:18:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
