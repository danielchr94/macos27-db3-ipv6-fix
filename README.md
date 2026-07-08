# macOS 27 DB3 IPv6 Fix

A tiny menu bar app that works around the IPv6 networking bug in **macOS 27 developer
beta 3**, which makes Chromium-based apps and similar (Chrome, Electron apps, Node tools)
stall and disconnect.

One click to turn the fix on, one click to turn it off.

## The bug

macOS 27 db3 advertises IPv6 on Wi-Fi with only a link-local address and **no working
route** (`ping6` returns "No route to host"). Apps that try IPv6 first - Chromium-based apps
and similar (Chrome, Electron apps, Node tools) - stall or drop their connections. Safari
stays fine because it sticks to IPv4.

Disabling IPv6 on the Wi-Fi service resolves it, and that setting is persistent across
reboots - so that is all this app does.

## What this app does

**Enable Fix**
- Turns off IPv6 on your Wi-Fi service. That is the whole fix, and it stays off across
  reboots. No background service, no daemon.

**Disable Fix**
- Sets Wi-Fi IPv6 back to **Automatic** (the macOS default).

The app is a menu bar item only (no dock icon, no window). It needs your admin password when
you enable or disable, because it changes a network setting.

> Upgrading from 1.0? That version installed an auto-heal `LaunchDaemon` that cleaned leaked
> IPv6 routes on a timer. It turned out to cause periodic drops and was unnecessary, so it is
> gone. Enable or Disable in 1.1 automatically removes the old daemon if it is still present.

## Install (non-technical)

1. Download `macOS-27-DB3-IPv6-Fix.zip` from the [`dist/`](dist/) folder (or the Releases
   page) and unzip it.
2. Move **macOS 27 DB3 IPv6 Fix.app** to your Applications folder.
3. **First launch:** right-click the app and choose **Open**, then confirm. This is needed
   once because the app is not notarized by Apple (see below). After that it opens normally.
4. Click the menu bar icon and choose **Enable Fix**. Enter your Mac password when asked.
5. Restart any affected app (Chromium-based apps and similar) if it was open.

To turn it off later: menu bar icon -> **Disable Fix**.

## Uninstall

1. Menu bar icon -> **Disable Fix** (restores default IPv6, and removes the 1.0 daemon if
   it is still present).
2. Quit the app and drag it to the Trash.

If you ever need to clean up manually from Terminal (also clears the old 1.0 daemon):

```bash
sudo launchctl bootout system /Library/LaunchDaemons/io.github.danielchr94.macos27db3ipv6fix.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/io.github.danielchr94.macos27db3ipv6fix.plist
sudo rm -rf "/Library/Application Support/macos27-db3-ipv6-fix"
sudo networksetup -setv6automatic "Wi-Fi"
```

## Build from source

Requires the Xcode command line tools (`swiftc`).

```bash
bash build.sh
```

This compiles `Sources/main.swift`, assembles the `.app` bundle, ad-hoc signs it, and writes
both the app and a distributable zip into `dist/`.

## Security and trust

- The app is **ad-hoc signed, not notarized**, because it is not distributed through an Apple
  Developer account. That is why macOS asks you to confirm on first launch. If you prefer, you
  can build it yourself from source with `build.sh`.
- Everything the app runs is visible: the exact privileged scripts are in
  [`Resources/`](Resources/) and embedded verbatim in `Sources/main.swift`.
- The only change it makes is toggling IPv6 on the Wi-Fi service (`networksetup -setv6off` /
  `-setv6automatic`). It runs no background process.

## Note

This is a workaround for an Apple beta defect, not a permanent fix. Please also report the
issue to Apple through **Feedback Assistant** so it gets fixed properly. Not affiliated with
Apple or Microsoft.

## License

MIT - see [LICENSE](LICENSE).
