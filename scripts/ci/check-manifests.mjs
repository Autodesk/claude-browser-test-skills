// Validate the plugin/marketplace manifests: parse as JSON and check the
// fields Claude Code requires for a published plugin.
import { readFileSync } from "node:fs";

const errors = [];

function load(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    errors.push(`${path}: invalid JSON — ${e.message}`);
    return null;
  }
}

const mp = load(".claude-plugin/marketplace.json");
const pl = load(".claude-plugin/plugin.json");

if (mp) {
  if (!mp.name) errors.push("marketplace.json: missing 'name'");
  if (!mp.owner || !mp.owner.name) errors.push("marketplace.json: missing 'owner.name'");
  if (!Array.isArray(mp.plugins) || mp.plugins.length === 0)
    errors.push("marketplace.json: 'plugins' must be a non-empty array");
}

if (pl) {
  if (!pl.name) errors.push("plugin.json: missing 'name'");
  if (!pl.description) errors.push("plugin.json: missing 'description'");
}

if (mp && pl && Array.isArray(mp.plugins)) {
  const named = mp.plugins.some((p) => p.name === pl.name);
  if (!named)
    errors.push(`marketplace.json: no plugin entry matches plugin.json name '${pl.name}'`);
}

if (errors.length) {
  for (const e of errors) console.error(`::error::${e}`);
  process.exit(1);
}
console.log("manifests: OK");
