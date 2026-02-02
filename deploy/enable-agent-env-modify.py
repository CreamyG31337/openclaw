#!/usr/bin/env python3
"""Enable agent to modify its own environment: exec on gateway host, sandbox off."""
import json
p = "/home/lance/.openclaw/openclaw.json"
with open(p) as f:
    c = json.load(f)
# Sandbox off = exec runs on gateway host (container), so agent can edit config, run commands in container
c.setdefault("agents", {}).setdefault("defaults", {})
c["agents"]["defaults"].setdefault("sandbox", {})
c["agents"]["defaults"]["sandbox"]["mode"] = "off"
# Optional: explicit exec on gateway, no approval prompt for this setup (Docker single-tenant)
c.setdefault("tools", {})
c["tools"].setdefault("exec", {})
c["tools"]["exec"]["host"] = "gateway"
with open(p, "w") as f:
    json.dump(c, f, indent=2)
print("OK: sandbox=off, exec.host=gateway")
