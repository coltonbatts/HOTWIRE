import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set activation policy BEFORE the app finishes launching
        // This ensures it appears in the Dock immediately
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate and bring to front
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure the window is visible and front
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When clicking dock icon, show the window
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

@main
struct HotwireApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
