#!/usr/bin/env bash
# Verify every skills/*/SKILL.md has valid plugin-skill frontmatter:
#  - a `name` and `description` are present
#  - `name` is the BARE skill name (no `plugin:` prefix — Claude Code adds the
#    `browser-test:` namespace automatically; a prefixed name is a bug)
#  - `name` matches its directory (warning only)
set -euo pipefail

fail=0
shopt -s nullglob
files=(skills/*/SKILL.md)
if [ ${#files[@]} -eq 0 ]; then
  echo "::error::no skills/*/SKILL.md files found"
  exit 1
fi

for f in "${files[@]}"; do
  fm=$(awk 'NR==1 && $0=="---"{inb=1; next} inb && $0=="---"{exit} inb{print}' "$f")
  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)
  desc=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)

  if [ -z "$name" ]; then echo "::error file=$f::missing 'name' in frontmatter"; fail=1; fi
  if [ -z "$desc" ]; then echo "::error file=$f::missing 'description' in frontmatter"; fail=1; fi

  case "$name" in
    *:*)
      echo "::error file=$f::skill name '$name' must be bare (no plugin prefix); the namespace is applied automatically"
      fail=1
      ;;
  esac

  dir=$(basename "$(dirname "$f")")
  if [ -n "$name" ] && [ "$name" != "$dir" ]; then
    echo "::warning file=$f::skill name '$name' does not match directory '$dir'"
  fi
done

if [ "$fail" -eq 0 ]; then echo "SKILL.md frontmatter: OK (${#files[@]} skills)"; fi
exit "$fail"
