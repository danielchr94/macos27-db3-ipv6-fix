#!/bin/bash
# Reference copy of the privileged Disable action embedded in the app.
# Run as root. Removes any legacy daemon, then restores default Wi-Fi IPv6.
PLIST="/Library/LaunchDaemons/io.github.danielchr94.macos27db3ipv6fix.plist"
SUPPORT_DIR="/Library/Application Support/macos27-db3-ipv6-fix"

if [ -f "$PLIST" ]; then launchctl bootout system "$PLIST" 2>/dev/null || true; rm -f "$PLIST"; fi
rm -rf "$SUPPORT_DIR"

WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$SVC" ] && SVC="Wi-Fi"
networksetup -setv6automatic "$SVC"
exit 0
