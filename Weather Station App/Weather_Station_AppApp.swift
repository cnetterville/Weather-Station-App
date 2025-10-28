//
//  Weather_Station_AppApp.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

@main
struct Weather_Station_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .animation(.none) // Disable global animations that could cause jumping
                .onAppear {
                    // Initialize the menu bar manager when app starts
                    _ = MenuBarManager.shared
                    
                    // Disable automatic animations globally
                    NSAnimationContext.current.duration = 0
                    
                    print("🚀 App started - setting up notification listeners at app level")
                    
                    // Set up notification observer at the app level where it's guaranteed to work
                    NotificationCenter.default.addObserver(
                        forName: .bringAppToFront,
                        object: nil,
                        queue: .main
                    ) { _ in
                        print("🔔 App level received bringAppToFront notification!")
                        
                        // Check if main window exists
                        let mainWindow = NSApp.windows.first { window in
                            !window.className.contains("StatusBar") && 
                            !window.className.contains("Item")
                        }
                        
                        if let window = mainWindow {
                            print("🎯 Found existing main window - bringing to front")
                            window.deminiaturize(nil)
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                            
                        } else {
                            print("🏗️ No main window - creating new window")
                            
                            // The proper SwiftUI way to open a new window
                            DispatchQueue.main.async {
                                // This should trigger WindowGroup to create a new window
                                let newWindow = NSWindow(
                                    contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
                                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                    backing: .buffered,
                                    defer: false
                                )
                                
                                // Set window properties
                                newWindow.title = "Weather Station App"
                                newWindow.center()
                                newWindow.makeKeyAndOrderFront(nil)
                                
                                // Create the content view
                                let contentView = NSHostingView(rootView: ContentView())
                                newWindow.contentView = contentView
                                
                                print("✅ Created new main window")
                            }
                        }
                    }
                    
                    // Test notification after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        print("🧪 Sending test notification from app level")
                        NotificationCenter.default.post(name: .bringAppToFront, object: nil)
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