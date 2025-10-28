//
//  Weather_Station_AppApp.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

// AppDelegate to handle notifications when no windows exist
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 AppDelegate: App finished launching")
        
        // Set up observer for showing main window when needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowMainWindow),
            name: .showMainWindow,
            object: nil
        )
    }
    
    @objc func handleShowMainWindow() {
        print("📱 AppDelegate: Received showMainWindow notification")
        
        // Check if there are any existing main windows
        let hasMainWindow = NSApp.windows.contains { window in
            !window.className.contains("StatusBar") && 
            !window.className.contains("Item") &&
            window.contentView != nil &&
            window.frame.width > 500
        }
        
        if hasMainWindow {
            print("✅ AppDelegate: Main window already exists, letting ContentView handle it")
            return
        }
        
        print("📱 AppDelegate: No main window exists, creating new one")
        
        // Create a new window with proper SwiftUI lifecycle management
        DispatchQueue.main.async {
            // Use NSApp's built-in mechanism to create a new untitled document/window
            // This will trigger SwiftUI to create a new WindowGroup instance
            if NSApp.responds(to: #selector(NSDocumentController.newDocument(_:))) {
                NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
                print("✅ AppDelegate: Sent newDocument action")
            } else {
                // Fallback: Try to trigger File > New menu item
                if let fileMenu = NSApp.mainMenu?.item(withTitle: "File"),
                   let newItem = fileMenu.submenu?.items.first(where: { $0.title.contains("New") }) {
                    NSApp.sendAction(newItem.action!, to: newItem.target, from: newItem)
                    print("✅ AppDelegate: Triggered File > New menu item")
                } else {
                    print("❌ AppDelegate: Could not find way to create new window")
                }
            }
            
            // Ensure the app is active
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct Weather_Station_AppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Main") {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .animation(.none)
                .onAppear {
                    // Initialize the menu bar manager when app starts
                    _ = MenuBarManager.shared
                    
                    // Disable automatic animations globally
                    NSAnimationContext.current.duration = 0
                    
                    print("🚀 ContentView appeared")
                }
                .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
                    // Handle the notification within the SwiftUI context
                    print("📱 ContentView: Received showMainWindow notification")
                    
                    // Since we're already in a ContentView, this window should already be visible
                    // Just ensure the app is activated and window is brought forward
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        
                        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { window in
                            !window.className.contains("StatusBar") && 
                            !window.className.contains("Item") &&
                            window.contentView != nil
                        }) {
                            if window.isMiniaturized {
                                window.deminiaturize(nil)
                            }
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                            print("✅ Activated existing window from ContentView")
                        } else {
                            print("⚠️ No main window found in ContentView")
                        }
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Add menu bar commands
            CommandGroup(after: .appInfo) {
                Button("Show in Menu Bar") {
                    MenuBarManager.shared.isMenuBarEnabled.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command])
            }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}