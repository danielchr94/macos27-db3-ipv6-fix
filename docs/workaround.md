# Manual workaround (for reference)

If you would rather apply the fix by hand instead of using the app, here are the exact steps
and how to revert them once Apple fixes the bug.

## Apply

### 1. Disable IPv6 on Wi-Fi

```bash
sudo networksetup -setv6off "Wi-Fi"
```

### 2. Delete the dead IPv6 default routes on the utun tunnels

These point at link-local gateways that go nowhere. Deleting them leaves the system with no
IPv6 default route, so apps stop trying IPv6.

```bash
netstat -rn -f inet6 | awk '$1=="default" && $NF ~ /^utun/ {print $NF}' | sort -u | \
  while read -r ifc; do sudo route -n delete -inet6 default -ifscope "$ifc"; done
# verify - should print nothing:
netstat -rn -f inet6 | grep "default.*utun"
```

The routes reappear after a reboot or a network change, so re-run this when needed - or let
the app's background service handle it automatically.

### 3. (Optional) Make Node resolve IPv4 first

Helpful for Node/Electron command line tools during the bug:

```bash
export NODE_OPTIONS="--dns-result-order=ipv4first"
```

Add that line to your shell profile (`~/.zshrc`) to make it persistent.

## Clear a stuck app's cache (if a Chromium-based app and similar is still misbehaving)

A Chromium-based or Electron app can hold onto dead sockets from before the fix. Quit it
fully, then clear its cache. Sandboxed apps keep it under their container; the path pattern
is `~/Library/Containers/<app-bundle-id>/Data/Library/Caches`:

```bash
rm -rf ~/Library/Containers/<app-bundle-id>/Data/Library/Caches/*
```

If you hit "Operation not permitted", grant your terminal Full Disk Access in
System Settings -> Privacy & Security -> Full Disk Access, or delete the folder from Finder.

## Revert to defaults (once the OS bug is fixed)

```bash
sudo networksetup -setv6automatic "Wi-Fi"     # step 1
# remove the NODE_OPTIONS line from ~/.zshrc    # step 3
# reboot to restore default IPv6 routes          # step 2
```

Then confirm IPv6 works again:

```bash
networksetup -getinfo "Wi-Fi" | grep IPv6       # expect: IPv6: Automatic
ping6 -c3 google.com                             # expect: replies, no "No route to host"
```
