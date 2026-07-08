## What & why

Briefly describe the change and the motivation. Link any related issue (e.g. `Closes #123`).

## Type of change

- [ ] Skill behavior (`skills/*/SKILL.md`)
- [ ] Plugin manifests (`.claude-plugin/`)
- [ ] Docs
- [ ] CI / tooling

## Checklist

- [ ] Local checks pass: `node scripts/ci/check-manifests.mjs`, `bash scripts/ci/check-skill-frontmatter.sh`, `bash scripts/ci/check-internal-refs.sh`
- [ ] `claude plugin validate .` passes
- [ ] No internal product names, credentials, or internal URLs introduced
- [ ] Skill `name` fields remain bare (no `browser-test:` prefix)
- [ ] Docs updated if behavior changed
