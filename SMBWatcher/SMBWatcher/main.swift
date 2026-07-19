import AppKit

// IMPORTANT: Do NOT replace this file with `@main` on AppDelegate.
//
// On this toolchain (Xcode 15.x / Swift 5.9+), `@main` on an NSApplicationDelegate
// does NOT synthesize the NSApplicationMain() entry point. The process launches
// (confirmed via ps, ApplicationType=UIElement in logs) but applicationDidFinishLaunching
// is never called — the app is alive but hollow. No status bar icon, no menus, nothing.
//
// This explicit entry point is the correct and only reliable way to launch a
// non-SwiftUI AppKit app. If you remove this file and add `@main` back to
// AppDelegate, the app will silently fail to initialize. See git history for
// the full diagnostic investigation.
//
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
