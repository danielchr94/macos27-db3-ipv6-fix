#!/bin/bash
# Remove IPv6 default routes leaked onto utun tunnels by the macOS 27 db3 bug.
# Idempotent and cheap; run periodically by the LaunchDaemon.
netstat -rn -f inet6 2>/dev/null | awk '$1=="default" && $NF ~ /^utun/ {print $NF}' | sort -u | while read -r ifc; do
  route -n delete -inet6 default -ifscope "$ifc" >/dev/null 2>&1
done
exit 0
