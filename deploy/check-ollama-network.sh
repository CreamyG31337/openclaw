#!/usr/bin/env bash
set -e
echo "=== Gateway container (network mode + extra hosts) ==="
docker inspect openclaw-gateway --format 'NetworkMode: {{.HostConfig.NetworkMode}}' 2>/dev/null || echo "Container not found"
docker inspect openclaw-gateway --format 'ExtraHosts: {{.HostConfig.ExtraHosts}}' 2>/dev/null
echo ""
echo "=== Docker networks ==="
docker network ls
echo ""
echo "=== Gateway NetworkSettings.Networks ==="
docker inspect openclaw-gateway --format '{{json .NetworkSettings.Networks}}' 2>/dev/null
echo ""
echo "=== Ollama on host (port 11434) ==="
(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null) | grep 11434 || echo "Nothing listening on 11434"
curl -s -o /dev/null -w "Host curl 127.0.0.1:11434 -> HTTP %{http_code}\n" http://127.0.0.1:11434/api/tags 2>/dev/null || echo "Host cannot reach Ollama on 11434"
echo ""
echo "=== From inside gateway: getent hosts host.docker.internal ==="
docker exec openclaw-gateway getent hosts host.docker.internal 2>/dev/null || echo "getent failed"
echo ""
echo "=== From inside gateway: wget host.docker.internal:11434 ==="
docker exec openclaw-gateway wget -q -O- --timeout=3 http://host.docker.internal:11434/api/tags 2>/dev/null | head -c 300 || echo "FAILED: gateway cannot reach Ollama at host.docker.internal:11434"
echo ""
