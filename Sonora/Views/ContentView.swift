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
    @State private var memosPath: NavigationPath = NavigationPath()
    @StateObject private var onboardingConfiguration = OnboardingConfiguration.shared
    
    // Debug toggles removed
    
    var body: some View {
        mainAppContent
            .fullScreenCover(
                isPresented: Binding<Bool>(
                    get: { onboardingConfiguration.shouldShowOnboarding },
                    set: { onboardingConfiguration.shouldShowOnboarding = $0 }
                )
            ) {
                OnboardingView()
                    .interactiveDismissDisabled() // avoid accidental dismiss during setup
            }
    }
    
    @ViewBuilder
    private var mainAppContent: some View {
        TabView(selection: $selectedTab) {
            // Recording tab navigation
            NavigationStack {
                RecordingView()
            }
            .tabItem {
                Label("Record", systemImage: selectedTab == 0 ? "mic.circle.fill" : "mic.circle")
            }
            .tag(0)

            // Memos tab navigation with shared path
            NavigationStack(path: $memosPath) {
                MemosView(popToRoot: popToRoot, navigationPath: $memosPath)
                    .navigationDestination(for: Memo.self) { memo in
                        MemoDetailView(memo: memo)
                    }
            }
            .tabItem {
                Label("Memos", systemImage: selectedTab == 1 ? "list.bullet.circle.fill" : "list.bullet.circle")
            }
            .tag(1)

        }
        .animation(nil, value: selectedTab)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue == 1 {
                popToRoot()
            }
        }
    }
    
    private func popToRoot() {
        // Clear memos navigation stack and notify observers for legacy handlers
        memosPath = NavigationPath()
        EventBus.shared.publish(.navigatePopToRootMemos)
    }
}

#Preview {
    ContentView()
}
