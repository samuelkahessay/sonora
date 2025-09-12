//
//  ContentView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared
    
    var body: some View {
        Group {
            if onboardingConfiguration.shouldShowOnboarding {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale))
            } else {
                mainAppContent
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: onboardingConfiguration.shouldShowOnboarding)
    }
    
    @ViewBuilder
    private var mainAppContent: some View {
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
        .animation(nil, value: selectedTab)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue == 1 {
                popToRoot()
            }
        }
    }
    
    private func popToRoot() {
        EventBus.shared.publish(.navigatePopToRootMemos)
    }
}

#Preview {
    ContentView()
}
