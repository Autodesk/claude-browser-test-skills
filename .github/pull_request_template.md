## What & why

Briefly describe the change and the motivation.

## Related issue

<!-- Use a closing keyword (Closes/Fixes/Resolves) so the issue auto-closes when this PR merges to main. -->
Closes #

## Type of change

- [ ] Skill behavior (`skills/*/SKILL.md`)
- [ ] Plugin manifests (`.claude-plugin/`)
- [ ] Docs
- [ ] CI / tooling

## Checklist

- [ ] Linked the issue this PR resolves with a closing keyword (`Closes #NNN`)
- [ ] Local checks pass: `node scripts/ci/check-manifests.mjs`, `bash scripts/ci/check-skill-frontmatter.sh`, `bash scripts/ci/check-internal-refs.sh`
- [ ] `claude plugin validate .` passes
- [ ] No internal product names, credentials, or internal URLs introduced
- [ ] Skill `name` fields remain bare (no `browser-test:` prefix)
- [ ] Docs updated if behavior changed
