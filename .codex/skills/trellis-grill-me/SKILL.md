---
name: trellis-grill-me
description: "Pressure-test plans, PRDs, designs, and implementation approaches through relentless but focused questioning. Use when the user says grill me, pressure-test this plan, challenge my design, 拷问/质疑/压力测试方案, or when a Trellis PRD/technical approach needs deeper clarification before implementation."
---

# Trellis Grill Me

Use this skill to stress-test a plan before implementation. The mode is intentionally probing: keep questioning until the plan, trade-offs, and hidden assumptions are explicit enough to implement safely.

## Core contract

- Interview the user relentlessly about every important aspect of the plan until there is shared understanding.
- Walk the design tree one branch at a time; resolve upstream decisions before dependent details.
- Ask **one question per message**.
- For every question, include your recommended answer and a short reason.
- If the answer can be derived from the repo, existing Trellis task files, specs, docs, or quick inspection, do that first instead of asking.
- Record decisions immediately when a Trellis task is active.

## Relationship to Trellis

`trellis-brainstorm` discovers requirements broadly. `trellis-grill-me` is a sharper review mode for pressure-testing a concrete idea, PRD, or technical approach.

Use it in any of these situations:

1. **Inside planning**: harden `{TASK_DIR}/prd.md` before `task.py start`.
2. **During implementation**: pause when the current approach has unresolved assumptions; update the PRD or `info.md` before continuing.
3. **No active task**: provide lightweight plan review without creating a task, unless the user decides to implement the change.

## Startup steps

1. Check active Trellis task:
   ```bash
   python ./.trellis/scripts/task.py current --source
   ```
2. If a task is active, read:
   - `{TASK_DIR}/prd.md` if present
   - `{TASK_DIR}/info.md` if present
   - relevant files under `{TASK_DIR}/research/`
   - relevant `.trellis/spec/**/index.md` files when implementation constraints matter
3. If no task is active, summarize the plan from the conversation and inspect repo files only when needed.

## Question loop

Before asking, classify the next uncertainty:

| Type | Action |
| --- | --- |
| Derivable from code/docs/spec/task files | Inspect and record the answer; do not ask. |
| Blocking ambiguity | Ask one concrete question with your recommended answer. |
| Product/UX/maintenance preference | Offer 2-3 options, mark one as recommended, and ask the user to choose. |
| Non-MVP curiosity | Put it in out-of-scope / future notes instead of blocking. |

Question format:

```markdown
I want to pressure-test <topic>.

**Question**: <one focused question>

**My recommendation**: <recommended answer>

**Why**: <short trade-off / risk explanation>
```

## What to challenge

Cover the highest-risk branches first:

- Goal: what outcome matters and what is explicitly not included.
- Users/workflows: who uses this, when, and what success/failure looks like.
- State/data: persisted state, migrations, cache, idempotency, rollback.
- Interfaces: API/CLI/UI contracts, backwards compatibility, validation.
- Failure modes: offline/network errors, partial writes, retries, permission boundaries.
- Maintainability: consistency with existing patterns, testing burden, future extension.
- Acceptance criteria: what exact checks prove the plan is done.

Do not mechanically ask every category. Stop once the remaining uncertainty no longer changes implementation choices.

## Recording decisions

When a Trellis task is active:

- Update `prd.md` after each user answer:
  - move answered questions into `Requirements`, `Technical Approach`, `Acceptance Criteria`, `Out of Scope`, or `Decision (ADR-lite)`;
  - keep only unresolved items in `Open Questions`.
- If the discussion changes implementation details after work started, add or update `info.md` with the technical decision and rationale.
- If you perform research, write a concise artifact under `{TASK_DIR}/research/` and reference it from the PRD instead of pasting raw research into chat.

When no task is active:

- Keep output conversational and concise.
- If the user chooses to implement, return to the normal Trellis flow: create a task, load `trellis-brainstorm`, seed/update `prd.md`, then continue.

## Stop condition

Stop grilling and summarize when all are true:

- The goal and MVP boundary are explicit.
- Major implementation-affecting choices have decisions.
- Failure/edge behavior is either specified or explicitly out of scope.
- Acceptance criteria are testable.
- The next implementation step is clear.

End with a short summary:

```markdown
Grill result:
- Decisions made: ...
- Remaining risks: ...
- PRD/task updates: ...
- Recommended next step: ...
```

## Anti-patterns

- Do not ask broad multi-question lists.
- Do not ask the user for information that local files can answer.
- Do not continue probing after the uncertainty no longer affects the MVP.
- Do not treat this skill as permission to skip Trellis task creation for actual implementation work.
- Do not leave decisions only in chat when a Trellis task exists.
