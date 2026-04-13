//
//  Weather_Station_AppApp.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

// Window delegate that hides the window on close instead of destroying it (for menu bar mode)
class MainWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If menu bar is enabled, hide the window instead of closing it
        if MenuBarManager.shared.isMenuBarEnabled {
            logUI("Hiding main window instead of closing (menu bar mode)")
            sender.orderOut(nil)
            return false
        }
        return true
    }
}

// AppDelegate to handle app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    let mainWindowDelegate = MainWindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        logSuccess("AppDelegate: App finished launching")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when menu bar mode is active
        return !MenuBarManager.shared.isMenuBarEnabled
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func showMainWindow() {
        logUI("AppDelegate: Showing main window")

        // Find hidden main window and show it
        if let window = NSApp.windows.first(where: { window in
            !window.className.contains("StatusBar") &&
            !window.className.contains("Item") &&
            window.contentView != nil &&
            window.title == "Main"
        }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            logSuccess("AppDelegate: Showed existing hidden window")
        } else {
            // No window exists at all - create a new one
            logUI("AppDelegate: No window found, creating new one")
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct Weather_Station_AppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Main") {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Initialize the menu bar manager when app starts
                    _ = MenuBarManager.shared

                    // Disable automatic animations globally
                    NSAnimationContext.current.duration = 0

                    // Configure window: save frame, install delegate, ensure proper sizing
                    DispatchQueue.main.async {
                        if let window = NSApp.windows.first(where: { window in
                            window.title == "Main" &&
                            !window.className.contains("StatusBar") &&
                            !window.className.contains("Item") &&
                            window.contentView != nil
                        }) ?? NSApp.mainWindow {
                            window.setFrameAutosaveName("MainWindow")

                            // Install our delegate to intercept window close
                            window.delegate = (NSApp.delegate as? AppDelegate)?.mainWindowDelegate

                            // Ensure the window meets minimum size on first appearance
                            if window.frame.width < 800 || window.frame.height < 600 {
                                let newWidth = max(window.frame.width, 1200)
                                let newHeight = max(window.frame.height, 800)
                                window.setContentSize(NSSize(width: newWidth, height: newHeight))
                                window.center()
                            }
                        }
                    }

                    logSuccess("ContentView appeared")
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Add menu bar commands
            CommandGroup(after: .appInfo) {
                Button("Show in Menu Bar") {
                    MenuBarManager.shared.isMenuBarEnabled.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command])
            }
            
            // Ensure Quit command is available (especially important for menu bar apps)
            CommandGroup(replacing: .appTermination) {
                Button("Quit Weather Station App") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}