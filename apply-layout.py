#!/usr/bin/env python3
"""Apply Shelfish settings to ~/.config/omarchy/shell.json.

Quattro only lets `bar`-kind plugins mutate the bar layout, so Shelfish hands its
serialized settings to this helper. It stores them on the Shelfish entry and
places every group member beside its group button; visibility is runtime state.

Usage: apply-layout.py <module-name> <group-prefix> <source-dir> <payload-json>
       apply-layout.py <module-name> <group-prefix> <source-dir> --restore

--restore removes the generated group buttons and leaves members in place.
"""
import json
import os
import re
import sys
import tempfile

module, prefix, source_dir = sys.argv[1], sys.argv[2], sys.argv[3]
restore = sys.argv[4] == "--restore"
payload = {} if restore else json.loads(sys.argv[4])
path = os.path.expanduser("~/.config/omarchy/shell.json")
SETTINGS = "shelfish.settings"


def parse(value, fallback):
    if isinstance(value, str):
        try:
            return json.loads(value)
        except ValueError:
            return fallback
    return value if value is not None else fallback


with open(path) as f:
    config = json.load(f)

layout = config.setdefault("bar", {}).setdefault("layout", {})
sections = [layout[s] for s in ("left", "center", "right") if isinstance(layout.get(s), list)]
host = next((e for sec in sections for e in sec if isinstance(e, dict) and e.get("id") == module), None)
if host is None:
    sys.exit("shelfish entry not found in bar layout")

def write(config):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".shell.json.")
    with os.fdopen(fd, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)


def entry_id(entry):
    return entry.get("id", "") if isinstance(entry, dict) else str(entry)


if restore:
    for sec in sections:
        sec[:] = [e for e in sec if not entry_id(e).startswith(prefix)]
    write(config)
    sys.exit(0)

host.update(payload)
groups = parse(host.get("groups"), [])
widget_configs = parse(host.get("widgetConfigs"), {})
members = {w for g in groups for w in g.get("widgets", []) if w not in (module, "omarchy.tray", SETTINGS)}

# Pull out generated entries and members, remembering each member's full entry.
for sec in sections:
    kept = []
    for entry in sec:
        eid = entry_id(entry)
        if eid.startswith(prefix):
            continue
        if eid in members:
            widget_configs[eid] = entry
            continue
        kept.append(entry)
    sec[:] = kept

additions = []
for g in groups:
    button = {"id": f"{prefix}{g['id']}", "source": f"{source_dir}/GroupButton.qml", "shelfishGroupId": g["id"]}
    group_members = []
    for w in g.get("widgets", []):
        if w == SETTINGS:
            group_members.append({"id": f"{prefix}{g['id']}.settings", "source": f"{source_dir}/SettingsButton.qml", "shelfishGroupId": g["id"]})
        elif w in members:
            group_members.append(widget_configs.get(w, {"id": w}))
    additions += group_members + [button] if g.get("direction") == "left" else [button] + group_members

for sec in sections:
    for i, entry in enumerate(sec):
        if isinstance(entry, dict) and entry.get("id") == module:
            sec[i + 1:i + 1] = additions
            break

# The shell's config loader treats doubled braces as templates, so keep them apart.
def safe(value):
    text = json.dumps(value, separators=(",", ":"), ensure_ascii=False)
    text = re.sub(r"\}{2,}", lambda m: " ".join(m.group()), text)
    return re.sub(r"\{{2,}", lambda m: " ".join(m.group()), text)

host["widgetConfigs"] = safe({k: v for k, v in widget_configs.items() if k in members})

write(config)
