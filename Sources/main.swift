import AppKit

// macOS 27 DB3 IPv6 Fix
// Lightweight menu bar app that toggles the IPv6 workaround for the macOS 27
// developer beta 3 bug where Wi-Fi advertises unusable IPv6, stalling
// Chromium-based apps and similar (Chrome, Electron apps, Node tools).
//
// The fix is simply disabling IPv6 on the Wi-Fi service. That setting is
// persistent across reboots, so no background daemon is needed.

let bundleID = "io.github.danielchr94.macos27db3ipv6fix"
let appVersion = "1.1.0"

// Detect the Wi-Fi service name, fall back to "Wi-Fi". No admin needed.
let wifiServiceSnippet = #"""
WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$SVC" ] && SVC="Wi-Fi"
"""#

// Enable: remove any legacy daemon, then disable IPv6 on Wi-Fi (persistent).
let enableScript = #"""
#!/bin/bash
set -e
PLIST="/Library/LaunchDaemons/io.github.danielchr94.macos27db3ipv6fix.plist"
SUPPORT_DIR="/Library/Application Support/macos27-db3-ipv6-fix"
if [ -f "$PLIST" ]; then launchctl bootout system "$PLIST" 2>/dev/null || true; rm -f "$PLIST"; fi
rm -rf "$SUPPORT_DIR"
WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$SVC" ] && SVC="Wi-Fi"
networksetup -setv6off "$SVC"
exit 0
"""#

// Disable: remove any legacy daemon, then restore Wi-Fi IPv6 to Automatic.
let disableScript = #"""
#!/bin/bash
PLIST="/Library/LaunchDaemons/io.github.danielchr94.macos27db3ipv6fix.plist"
SUPPORT_DIR="/Library/Application Support/macos27-db3-ipv6-fix"
if [ -f "$PLIST" ]; then launchctl bootout system "$PLIST" 2>/dev/null || true; rm -f "$PLIST"; fi
rm -rf "$SUPPORT_DIR"
WIFI_DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $NF}')
SVC=$(networksetup -listnetworkserviceorder | awk -v dev="$WIFI_DEV" '/^\([0-9]+\)/{name=substr($0,index($0,")")+2)} index($0,"Device: " dev ")"){print name; exit}')
[ -z "$SVC" ] && SVC="Wi-Fi"
networksetup -setv6automatic "$SVC"
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

    // The fix is on when IPv6 is Off on the Wi-Fi service. Read-only, no admin.
    func isEnabled() -> Bool {
        let script = wifiServiceSnippet + "\nnetworksetup -getinfo \"$SVC\" | grep -q '^IPv6: Off' && echo yes || echo no"
        return runCapture("/bin/bash", ["-c", script]).contains("yes")
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
            ? "IPv6 is now disabled on Wi-Fi. This is the stable fix and it stays off across reboots. Quit and reopen any app that was already running (Chromium-based apps and similar) so it drops its dead connections."
            : "Wi-Fi IPv6 was set back to Automatic (the macOS default)."
        alert.runModal()
    }

    // Run a small command, return stdout. Used for read-only state checks.
    func runCapture(_ launchPath: String, _ args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return "" }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
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
        macOS 27 developer beta 3 advertises IPv6 with no working route, which stalls apps that try IPv6 first - Chromium-based apps and similar (Chrome, Electron apps, Node tools).

        Enable Fix - disables IPv6 on your Wi-Fi service. That is the stable fix and it stays off across reboots.
        Disable Fix - sets Wi-Fi IPv6 back to Automatic.

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
