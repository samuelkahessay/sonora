//
//  SonoraApp.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

@main
struct SonoraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Configure DIContainer with shared service instances
                    DIContainer.shared.configure()
                    print("🚀 SonoraApp: DIContainer configured with shared services")
                    
                    // Register event handlers for reactive features
                    EventHandlerRegistry.shared.registerAllHandlers()
                    print("🎯 SonoraApp: Event handlers registered and active")
                    
                    // Test event flow in debug builds
                    #if DEBUG
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        EventHandlerRegistry.shared.testEventFlow()
                        
                        // Additional verification - check handler status
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("🔍 Event Handler Status:")
                            print(EventHandlerRegistry.shared.detailedStatus)
                            
                            if let memoHandler = EventHandlerRegistry.shared.getHandler("MemoEventHandler", as: MemoEventHandler.self) {
                                print("📊 MemoEventHandler Statistics:")
                                print(memoHandler.handlerStatistics)
                            }
                        }
                    }
                    #endif
                }
        }
    }
}
