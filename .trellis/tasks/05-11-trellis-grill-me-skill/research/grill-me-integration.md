# Research: grill-me skill integration

## Source

Matt Pocock skill: `skills/productivity/grill-me/SKILL.md` at https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md

## Relevant original behavior

The upstream skill is intentionally small. Its core contract is:

- Interview the user relentlessly about every aspect of a plan until shared understanding is reached.
- Walk down the design tree one branch at a time, resolving dependencies between decisions.
- For each question, provide the assistant's recommended answer.
- Ask one question at a time.
- If a question can be answered by exploring the codebase, explore the codebase instead.

## Fit with this Trellis project

`trellis-brainstorm` already embeds similar ideas, but it is a broad requirements-discovery workflow that creates/seeds tasks and PRDs. A dedicated Trellis-flavored grill skill is still useful as a named pressure-test mode:

- before implementation, to harden an existing PRD/plan;
- inside brainstorm, when a specific plan needs adversarial questioning;
- outside a task, for lightweight Q&A or design review without forcing task creation.

## Recommended integration

Create a project-local skill named `trellis-grill-me`, not plain `grill-me`, because:

- it clarifies the skill is adapted to Trellis artifacts and PRD updates;
- it avoids colliding with any future user-global `grill-me` skill;
- it can route explicitly from `.trellis/workflow.md` alongside other Trellis skills.

Install it in the shared `.agents/skills/` layer and mirror to platform skill directories already present in this repository (`.claude/skills`, `.cursor/skills`, `.opencode/skills`, `.agent/skills`) so cross-tool Trellis usage remains consistent.
