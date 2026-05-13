# Check: trellis-grill-me skill

## Verification performed

- Confirmed skill exists in all intended local platform locations:
  - `.agents/skills/trellis-grill-me/SKILL.md`
  - `.claude/skills/trellis-grill-me/SKILL.md`
  - `.cursor/skills/trellis-grill-me/SKILL.md`
  - `.opencode/skills/trellis-grill-me/SKILL.md`
  - `.agent/skills/trellis-grill-me/SKILL.md`
- Ran a lightweight frontmatter validator for all five files:
  - `name` is `trellis-grill-me`
  - description is non-empty
  - skill name matches lowercase/hyphen naming rules
  - description contains trigger terms for `grill` and `pressure-test`
- Confirmed `.trellis/workflow.md` Skill Routing contains `trellis-grill-me` in both routing groups.
- Confirmed platform start docs mention `trellis-grill-me` for explicit pressure-test/grill requests where applicable.

## Note

The `skill-creator` bundled `quick_validate.py` script could not run in this environment because the available Python environments do not include `yaml` (`ModuleNotFoundError: No module named 'yaml'`). I used a local validator for the required frontmatter and naming checks instead.
