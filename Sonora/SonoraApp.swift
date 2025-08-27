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
                }
        }
    }
}
