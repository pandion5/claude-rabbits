# rabbits 🐇

*Korean original: [README.md](README.md)*

An autonomous subagent orchestration plugin for Claude Code.

The main session becomes the **lead rabbit (orchestrator)**: it plans the work, then casts,
dispatches, supervises, reviews, and coaches disposable, purpose-built expert **worker rabbits
(subagents)**, driving everything through to completion **fully autonomously**.

> The lead rabbit takes the task → assembles a team → dispatches it → supervises, reviews, and
> sends work back for rework → finishes and reports.

## Installation

```bash
claude plugin marketplace add pandion5/claude-rabbits
claude plugin install rabbits@rabbits
```

- Verify it loaded: `claude plugin list`, or check the Installed tab in the `/plugin` UI for `rabbits`.
- Update: `claude plugin update rabbits@rabbits`.

### Local development install

```bash
claude --plugin-dir "<repo path>"
```

- In POSIX shells such as Git Bash, always quote the path (to keep backslashes from being consumed).
- To pick up plugin file changes: restart the session, or run `/reload-plugins` mid-session.
  The global install is a cached snapshot — after changing the repo, run
  `claude plugin update rabbits@rabbits`.

## Usage

```
/rabbits:run <task to handle autonomously through to completion>
```

Natural-language triggers are also supported: "orchestrate this for me," "put together a team and
handle it," "let the rabbits loose."

**Tip — for long runs, pairing with `/goal` is recommended** (Claude Code v2.1.139+):

```
/goal rabbits 런 최종 리포트가 출력되고 미해결 항목 0건
/rabbits:run <작업>
```
(English: the `/goal` condition reads "the rabbits run prints a final report and zero items remain
unresolved," followed by `/rabbits:run <task>`.)

rabbits' "no giving up" rule is only a prompt-level contract, so if the lead rabbit mistakenly
believes it's done, nothing stops it from ending early. Setting `/goal` adds an independent
evaluator (the harness's Stop hook) that judges the condition every turn and forces the turn to
resume if it isn't met — the harness supplies the independent judge and enforcement power that
rabbits itself lacks. `/goal` is a native command, so only the user can set it (the lead rabbit
cannot set it on its own behalf).

### Backlog

Queue tasks in `.rabbits/backlog.md` using the format `- [ ] one-line task` (`- [x]` once done).
Every time `/rabbits:run` is invoked with no arguments, it picks up the topmost unfinished item,
processes it, and automatically chains into the next run until the backlog is exhausted — the stop
guard blocks premature exit and helps sustain the chaining (the same 8-block cap and Windows
fallback limits apply; chaining is capped at 10 items per invocation). `backlog.md` is tracked by
git (intentionally — for team sharing and history).

## How it works (6 stages)

| Stage | Name | What it does |
|-------|------|---------------|
| 0 | Intake | Pin down the goal and the definition of success |
| 1 | Planning | Decompose into subtasks → mini DAG + completion criteria; auto-decide specialist teams; build the roster; assemble the context pack once |
| 2 | Cast | 101 archetypes (8 core + 93 extended, lazy-loaded by domain) + 5 specialist team presets (tech, legal, security, search, QA) + model and time-limit assignment |
| 3 | Dispatch | Independent tasks run in parallel, dependent tasks run sequentially, long-running tasks run in background |
| 3.5 | Supervision | maxTurns as a first-line guard + time-limit watchdog + swap in a replacement worker if stalled |
| 4 | Review | Worker `rabbits-result` block (self_check) + rubric → PASS / REVISE / ESCALATE |
| 5 | Feedback | Coaching for rework → if that fails, the escalation ladder (no giving up) |
| 6 | Report | Integrate deliverables + final report |

### Specialist teams (presets)

| Team | Specialty |
|------|-----------|
| Tech team | Reviews technical feasibility (viability, risk, alternatives) |
| Legal team | Reviews licensing and commercial-use questions (not legal advice) |
| Security team | Checks for vulnerabilities, patches them, and rescans (defensive only) |
| Search team | Multimodal web + code sourcing, supports other teams |
| QA team | Functional verification and regression — walks the entire persistent QA list (`.rabbits/qa-checklist.md`) |

The lead rabbit deploys these automatically based on the nature of the task — no separate command
needed.

### Archetypes (101 total = 8 core + 93 extended)

**8 core archetypes** — standing roles loaded on every run:

| # | Archetype | Responsibility |
|---|-----------|-----------------|
| 1 | Researcher | Deep investigation and analysis (read-only) |
| 2 | Implementer | Writes and edits code to spec |
| 3 | Reviewer | Audits and verifies deliverables (judges only, makes no edits) |
| 4 | Tester | Writes, runs, and reports on tests |
| 5 | Planner | Decomposes and designs subdomains |
| 6 | Integrator | Merges multiple deliverables into the final assembly |
| 7 | Debugger | Reproduce → root cause → minimal fix |
| 8 | Verifier | Actually runs the deliverable and observes its behavior |

**93 extended archetypes** — kept on hand across 12 domains under `skills/run/archetypes-ext/`;
the lead rabbit lazy-loads only the domain file that matches a given subtask (to conserve tokens):

| Domain | Count | Examples |
|--------|-------|----------|
| Specialist review & special-purpose | 9 | Tech reviewer, security auditor, searcher, documentarian, UX analyst |
| Software deep-dive | 9 | Performance engineer, concurrency auditor, accessibility auditor |
| Data & AI | 9 | Model evaluator, prompt engineer, bias/fairness auditor |
| Infrastructure & operations | 8 | Deployment engineer, incident responder, disaster-recovery designer |
| Games & interactive | 7 | Balance tuner, level designer, game-feel tuner |
| Creative & content | 10 | Copywriter, humanizer, fact-checker |
| Business | 8 | Product manager, financial modeler, pricing strategist |
| Science & research | 7 | Statistical analyst, reproducibility verifier, literature synthesizer |
| Education | 6 | Curriculum designer, assessment-item designer, explainer writer |
| Media & AV | 7 | Audio engineer, color grader, motion-graphics designer |
| Privacy & compliance | 6 | Privacy auditor, regulatory-compliance mapper, audit-trail designer |
| Growth & product | 7 | Onboarding designer, retention analyst, monetization designer |

See the extended catalog in `skills/run/archetypes.md` for the full list.

Fully autonomous: it does not ask the user anything mid-run (except for the 3 safety-valve
conditions — dangerous ambiguity, destructive actions, and genuine external blockers).

## File structure

```
rabbits/
├── .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json
├── hooks/
│   ├── hooks.json        # Registers the Stop event → stop guard
│   └── stop-guard.sh     # Marker-based exit blocking (POSIX sh)
├── skills/run/
│   ├── SKILL.md          # 6-stage protocol
│   ├── archetypes.md     # 8 core archetypes + shared rules + extended catalog index
│   ├── archetypes-ext/   # 93 extended archetypes (12 domains, lazy-loaded)
│   ├── teams.md          # 5 specialist team presets (tech, legal, security, search, QA)
│   └── review-rubric.md  # Review rubric + escalation ladder
└── README.md
```

No `agents/` folder — workers are improvised and disposable (not saved to files).

## Smoke-test checklist

- [x] **T1 — research task**: `/rabbits:run docs/ 아래 문서 구조와 핵심 결정을 조사해 요약 보고해줘`
      (English: "investigate the doc structure and key decisions under docs/ and report a summary")
      → confirmed: researcher workers dispatched in parallel + integrated report.
- [x] **T2 — small coding task**: `/rabbits:run scripts/greet.ps1을 만들어줘 — 이름 인자를 받아 인사를 출력, 한국어 주석`
      (English: "create scripts/greet.ps1 — take a name argument and print a greeting, with Korean comments")
      → confirmed: implementer dispatched + lead rabbit performs the rubric review (an independent
      reviewer worker is dispatched separately only for high-risk deliverables).
- [x] **T3 — multi-stage task**: `/rabbits:run 다음 3개를 각각 처리해줘 — (1) README 오탈자 점검 (2) skills/run/SKILL.md 단계 구조 요약 (3) docs/ 스펙의 확정 결정 D1~D6 재검증`
      (English: "handle these 3 items separately — (1) check the README for typos (2) summarize the
      stage structure of skills/run/SKILL.md (3) re-verify finalized decisions D1–D6 in the docs/ spec")
      → confirmed: parallel dispatch in a single message (3 Agent calls) + supervision + integration.
- [x] **T4 — feedback loop triggered**: `/rabbits:run 좋은 커밋 메시지 가이드 문서를 docs/commit-guide.md로 작성해줘`
      (English: "write a good commit-message guide to docs/commit-guide.md"; a task with deliberately
      loose completion criteria) → REVISE verdict → SendMessage coaching → same worker reworks it →
      re-review PASS (1 round), confirmed empirically.
- [x] **T5 — supervision triggered**: `/rabbits:run 이 리포 전체 문서의 상호참조를 조사해줘 — 조사 워커는 background로 파견하고 제한시간은 1분으로`
      (English: "investigate the cross-references across this repo's docs — dispatch the research
      worker in background with a 1-minute time limit") → confirmed empirically end to end:
      ScheduleWakeup armed and fired + completion notification wins the race when it arrives before
      the timer + elapsed-time checks (harnesses without status-polling support fall back to
      completion notifications and maxTurns) + one extension + forced termination via TaskStop.

## Constraints / notes

- This skill must run in the **main session** (never inside a fork or subagent) — it needs to be
  able to spawn workers via the Agent tool.
- Worker status polling and forced termination (TaskList/TaskGet/TaskStop), as well as mid-run
  nudges, depend on the harness — even where those aren't available, supervision still holds up via
  maxTurns + completion notifications + swapping in replacement workers.
- Run caps: 12 workers (18 max), 2 coaching rounds — once exhausted, it reports the best result
  obtained.
- **Stop hook stop guard**: while the `.rabbits/run-active.md` marker exists, it blocks exit and
  forces continuation through to Stage 6 completion (the harness's 8-block cap prevents an infinite
  loop). The marker is listed in `.gitignore` (never commit it) — a leftover marker from a crash
  that gets committed would block every session across the whole repo. On Windows without Git Bash,
  the PowerShell fallback means the sh script may not run — in that case the guard simply doesn't
  activate (a known limitation). When ending a turn to wait for a background worker's completion
  notification, rename the marker to `run-waiting.md` to pause the guard temporarily.
- **Knowledge base integration (optional)**: if a technical know-how index is injected into the
  session context, relevant know-how is folded into the Stage 1 pack, and if a recording skill is
  also available, verified new know-how gets recorded in Stage 6 — with neither present, this simply
  doesn't activate.
- **Worktree isolation (optional)**: if the harness's Agent tool supports it, workers that change
  files in parallel (or a single risky change worker) get isolated into a worktree to prevent
  conflicts — if unsupported or refused, it falls back to unisolated sequential execution. The
  worktree directory (`.claude/worktrees/`) is listed in `.gitignore` just like the marker (never
  commit it).
- **Cost of automatic backlog chaining**: an argument-less invocation keeps running for as many
  passes as the backlog is long, burning tokens proportionally — keep items small, and to stop,
  either delete backlog items or remove the run marker.

## Third-party notices

- `skills/humanizer/` bundles a copy of blader/humanizer v2.8.2 (Copyright (c) 2025 Siqi Chen, MIT
  License) — the original LICENSE is included.
