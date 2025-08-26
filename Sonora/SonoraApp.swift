//
//  SonoraApp.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

@main
struct SonoraApp: App {
    @StateObject private var memoStore = MemoStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(memoStore)
                .onAppear {
                    // Configure DIContainer with the shared MemoStore instance
                    // This ensures all ViewModels use the same service instances as EnvironmentObjects
                    DIContainer.shared.configure(memoStore: memoStore)
                    print("🚀 SonoraApp: DIContainer configured with shared services")
                }
        }
    }
}
