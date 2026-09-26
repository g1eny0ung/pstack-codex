### Authoring or modifying a skill

**You own the skill's voice.**

1. Use the host's **skill-creator** skill when available. Otherwise write a `SKILL.md` with a lowercase hyphenated `name`, a focused `description`, and portable relative references. Use `agents/openai.yaml` for supported Codex UI and invocation policy; preserve the user's requested activation behavior.
2. Validate the skill: frontmatter has `name` and `description`, referenced files exist, cross-skill links resolve.
3. Test cases if structural. Skip if subjective.
4. Apply **Opening a PR** when a PR is in scope; otherwise deliver the skill source and validation notes. Do not modify the installed plugin cache.

When in doubt, delete. Keep only prose that changes a decision. Tell it to do the thing and skip the reason. Explain only when the rule is confusing without one. Match tone to scope. Point at structural sources (types, READMEs, config) per the **encode-lessons-in-structure** principle skill. Delegate to other skills by path. Don't restate. A workflow you keep hitting but isn't captured → propose a new skill.

**Reply:** summary of the skill, key design decisions, validation notes.
