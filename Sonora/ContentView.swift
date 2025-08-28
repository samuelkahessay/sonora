//
//  ContentView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack {
            // Beautiful app-wide glass background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.05),
                    Color.teal.opacity(0.05),
                    Color.pink.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                RecordView()
                    .tabItem {
                        Label("Record", systemImage: selectedTab == 0 ? "mic.circle.fill" : "mic.circle")
                    }
                    .tag(0)
                
                MemosView(popToRoot: popToRoot)
                    .tabItem {
                        Label("Memos", systemImage: selectedTab == 1 ? "list.bullet.circle.fill" : "list.bullet.circle")
                    }
                    .tag(1)
            }
            .tint(theme.activeTheme.palette.primary)
            .onAppear {
                // Configure tab bar appearance with glass styling
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                
                // Glass background
                appearance.backgroundColor = UIColor.clear
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
                
                // Tab item styling
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor(theme.activeTheme.palette.primary)
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .foregroundColor: UIColor(theme.activeTheme.palette.primary),
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium)
                ]
                
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor(theme.activeTheme.palette.textSecondary)
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .foregroundColor: UIColor(theme.activeTheme.palette.textSecondary),
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular)
                ]
                
                // Apply appearance
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                
                // Add subtle shadow
                UITabBar.appearance().layer.shadowColor = UIColor(theme.activeTheme.palette.glassShadow).cgColor
                UITabBar.appearance().layer.shadowOpacity = 0.3
                UITabBar.appearance().layer.shadowOffset = CGSize(width: 0, height: -2)
                UITabBar.appearance().layer.shadowRadius = 8
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue == 1 && newValue == 1 {
                    popToRoot()
                }
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
