#!/bin/bash
# Reference copy of the privileged Disable action embedded in the app.
# Run as root. Removes the daemon and restores default Wi-Fi IPv6.
BUNDLE_ID="io.github.danielchr94.macos27db3ipv6fix"
SUPPORT_DIR="/Library/Application Support/macos27-db3-ipv6-fix"
PLIST="/Library/LaunchDaemons/$BUNDLE_ID.plist"

launchctl bootout system "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$SUPPORT_DIR"

WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
WIFI_SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$WIFI_SVC" ] && WIFI_SVC="Wi-Fi"
networksetup -setv6automatic "$WIFI_SVC"
exit 0
