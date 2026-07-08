#!/bin/bash
# Reference copy of the privileged Enable action embedded in the app.
# Run as root. Disables IPv6 on Wi-Fi and installs the auto-heal LaunchDaemon.
set -e
BUNDLE_ID="io.github.danielchr94.macos27db3ipv6fix"
SUPPORT_DIR="/Library/Application Support/macos27-db3-ipv6-fix"
CLEAN_SCRIPT="$SUPPORT_DIR/ipv6-route-clean.sh"
PLIST="/Library/LaunchDaemons/$BUNDLE_ID.plist"

WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
WIFI_SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$WIFI_SVC" ] && WIFI_SVC="Wi-Fi"
networksetup -setv6off "$WIFI_SVC"

mkdir -p "$SUPPORT_DIR"
cp "$(dirname "$0")/ipv6-route-clean.sh" "$CLEAN_SCRIPT"
chmod 755 "$CLEAN_SCRIPT"
chown root:wheel "$CLEAN_SCRIPT"

cp "$(dirname "$0")/launchdaemon.plist" "$PLIST"
chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl bootout system "$PLIST" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
exit 0
