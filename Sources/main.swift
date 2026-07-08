import AppKit

// macOS 27 DB3 IPv6 Fix
// Lightweight menu bar app that toggles the IPv6 workaround for the macOS 27
// developer beta 3 bug where Wi-Fi and utun tunnels advertise unusable IPv6,
// stalling Chromium-based apps and similar (Chrome, Electron apps, Node tools).

let bundleID = "io.github.danielchr94.macos27db3ipv6fix"
let plistPath = "/Library/LaunchDaemons/\(bundleID).plist"
let appVersion = "1.0.0"

// Enable: disable IPv6 on Wi-Fi, install the route-cleanup script, load a root
// LaunchDaemon that re-cleans the leaked utun IPv6 default routes every 60s.
let enableScript = #"""
#!/bin/bash
set -e
BUNDLE_ID="io.github.danielchr94.macos27db3ipv6fix"
SUPPORT_DIR="/Library/Application Support/macos27-db3-ipv6-fix"
CLEAN_SCRIPT="$SUPPORT_DIR/ipv6-route-clean.sh"
PLIST="/Library/LaunchDaemons/$BUNDLE_ID.plist"

# 1. Disable IPv6 on the Wi-Fi network service
WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
WIFI_SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$WIFI_SVC" ] && WIFI_SVC="Wi-Fi"
networksetup -setv6off "$WIFI_SVC"

# 2. Install the route-cleanup script (deletes dead IPv6 default routes on utun tunnels)
mkdir -p "$SUPPORT_DIR"
cat > "$CLEAN_SCRIPT" <<'CLEAN'
#!/bin/bash
# Remove IPv6 default routes leaked onto utun tunnels by the macOS 27 db3 bug.
netstat -rn -f inet6 2>/dev/null | awk '$1=="default" && $NF ~ /^utun/ {print $NF}' | sort -u | while read -r ifc; do
  route -n delete -inet6 default -ifscope "$ifc" >/dev/null 2>&1
done
exit 0
CLEAN
chmod 755 "$CLEAN_SCRIPT"
chown root:wheel "$CLEAN_SCRIPT"

# 3. Install and load the auto-heal LaunchDaemon
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$BUNDLE_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$CLEAN_SCRIPT</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>60</integer>
  <key>StandardErrorPath</key><string>/dev/null</string>
</dict>
</plist>
PLISTEOF
chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl bootout system "$PLIST" 2>/dev/null || true
launchctl bootstrap system "$PLIST"
exit 0
"""#

// Disable: stop and remove the daemon, delete the support files, restore Wi-Fi
// IPv6 to Automatic. Leaked utun routes clear on the next reboot.
let disableScript = #"""
#!/bin/bash
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
"""#

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "network", accessibilityDescription: "IPv6 Fix")
            img?.isTemplate = true
            button.image = img
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuild(menu)
    }

    func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let enabled = isEnabled()

        let status = NSMenuItem(title: enabled ? "Fix: Enabled" : "Fix: Disabled", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: enabled ? "Disable Fix" : "Enable Fix", action: #selector(toggleFix), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let about = NSMenuItem(title: "About / Help", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func toggleFix() {
        let enabling = !isEnabled()
        let script = enabling ? enableScript : disableScript
        guard runPrivileged(script) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = enabling ? "Fix enabled" : "Fix disabled"
        alert.informativeText = enabling
            ? "IPv6 was disabled on Wi-Fi and the auto-heal daemon is running. Chromium-based apps and similar should stop dropping now. Restart any that were open."
            : "The daemon was removed and Wi-Fi IPv6 was set back to Automatic. Leaked routes clear on the next reboot."
        alert.runModal()
    }

    // Run a shell script as root via one native admin prompt.
    func runPrivileged(_ shell: String) -> Bool {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("m27ipv6-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let scriptURL = dir.appendingPathComponent("run.sh")
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            try shell.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            return showError("Could not write helper script:\n\(error.localizedDescription)")
        }

        let osa = "do shell script \"/bin/bash \" & quoted form of \"\(scriptURL.path)\" with administrator privileges"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", osa]
        let errPipe = Pipe()
        proc.standardError = errPipe
        do {
            try proc.run()
        } catch {
            return showError("Could not launch osascript:\n\(error.localizedDescription)")
        }
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            // -128 is the user cancelling the authentication dialog; not an error.
            if msg.contains("-128") { return false }
            return showError("The command failed:\n\(msg)")
        }
        return true
    }

    @discardableResult
    func showError(_ text: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Something went wrong"
        alert.informativeText = text
        alert.runModal()
        return false
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "macOS 27 DB3 IPv6 Fix \(appVersion)"
        alert.informativeText = """
        macOS 27 developer beta 3 advertises IPv6 with no working route, which stalls apps that try IPv6 first - Chromium-based apps and similar (Chrome, Electron apps, Node tools). This tool disables IPv6 on Wi-Fi and runs a small background service that removes the dead IPv6 routes the OS keeps leaking onto its VPN tunnels.

        Enable Fix - applies the workaround and keeps it healed across reboots.
        Disable Fix - removes it and restores default IPv6 settings.

        This is a workaround for an Apple beta defect. Please also report it via Feedback Assistant.
        """
        alert.runModal()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
