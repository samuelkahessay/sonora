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
        }
    }
}
