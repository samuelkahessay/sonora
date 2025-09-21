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
    
#if DEBUG
    @AppStorage("debug.useMinimalSettings") private var debugUseMinimalSettings: Bool = false
    @AppStorage("debug.useMinimalMemos") private var debugUseMinimalMemos: Bool = true
    @AppStorage("debug.memos.usePathBinding") private var debugMemosUsePathBinding: Bool = true
    @AppStorage("debug.memos.inlineTitle") private var debugMemosInlineTitle: Bool = false
#endif
    
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
            // Recording tab navigation
            NavigationStack {
                RecordingView()
            }
            .tabItem {
                Label("Record", systemImage: selectedTab == 0 ? "mic.circle.fill" : "mic.circle")
            }
            .tag(0)

            // Memos tab navigation with shared path (DEBUG can switch to plain stack)
            memosTab
            .tabItem {
                Label("Memos", systemImage: selectedTab == 1 ? "list.bullet.circle.fill" : "list.bullet.circle")
            }
            .tag(1)

            // Test tab navigation
            NavigationStack {
                TestView()
            }
            .tabItem {
                Label("Test", systemImage: selectedTab == 2 ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .tag(2)

            // Settings tab navigation
            NavigationStack {
#if DEBUG
                if debugUseMinimalSettings {
                    SettingsMinimalView()
                } else {
                    SettingsView()
                }
#else
                SettingsView()
#endif
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
            }
            .tag(3)
        }
        .animation(nil, value: selectedTab)
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == 1 && newValue == 1 {
                popToRoot()
            }
        }
        // Log path changes for Phase 1b diagnostics
        .onChange(of: memosPath) { _ in
            print("[DEBUG] memosPath changed: newCount=\(memosPath.count)")
        }
    }

    // MARK: - Memos Tab Variants (DEBUG diagnostics)

    @ViewBuilder
    private var memosTab: some View {
#if DEBUG
        if debugUseMinimalMemos {
            if debugMemosUsePathBinding {
                NavigationStack(path: $memosPath) {
                    MemosMinimalView()
                        .onAppear { print("[DEBUG] MemosMinimalView (path-bound stack)") }
                        .navigationTitle("Memos")
                        .navigationBarTitleDisplayMode(debugMemosInlineTitle ? .inline : .large)
                }
                .navigationDestination(for: Memo.self) { memo in
                    MemoDetailView(memo: memo)
                }
                .onAppear { print("[DEBUG] Memos path count on appear: \(memosPath.count)") }
            } else {
                NavigationStack {
                    MemosMinimalView()
                        .onAppear { print("[DEBUG] MemosMinimalView (plain stack)") }
                        .navigationTitle("Memos")
                        .navigationBarTitleDisplayMode(debugMemosInlineTitle ? .inline : .large)
                }
                .navigationDestination(for: Memo.self) { memo in
                    MemoDetailView(memo: memo)
                }
                .onAppear { print("[DEBUG] Using plain stack for Memos (no path-binding)") }
            }
        } else {
            NavigationStack(path: $memosPath) {
                MemosView(popToRoot: popToRoot, navigationPath: $memosPath)
            }
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .onAppear { print("[DEBUG] MemosView path count on appear: \(memosPath.count)") }
        }
#else
        NavigationStack(path: $memosPath) {
            MemosView(popToRoot: popToRoot, navigationPath: $memosPath)
                .navigationTitle("Memos")
                .navigationBarTitleDisplayMode(.large)
        }
        .navigationDestination(for: Memo.self) { memo in
            MemoDetailView(memo: memo)
        }
#endif
    }
    
    private func popToRoot() {
        // Clear memos navigation stack and notify observers for legacy handlers
        print("[DEBUG] popToRoot invoked; clearing memosPath (current count=\(memosPath.count))")
        memosPath = NavigationPath()
        EventBus.shared.publish(.navigatePopToRootMemos)
    }
}

#Preview {
    ContentView()
}
