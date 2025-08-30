//
//  ContentView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: selectedTab == 0 ? "mic.circle.fill" : "mic.circle")
                }
                .tag(0)
            
            MemosView(popToRoot: popToRoot)
                .tabItem {
                    Label("Memos", systemImage: selectedTab == 1 ? "list.bullet.circle.fill" : "list.bullet.circle")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue == 1 {
                popToRoot()
            }
        }
    }
    
    private func popToRoot() {
        NotificationCenter.default.post(name: .popToRootMemos, object: nil)
    }
}

#Preview {
    ContentView()
}
