//
//  SonoraApp.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI
import SwiftData
import UIKit
import CoreSpotlight

@main
struct SonoraApp: App {
    @StateObject private var themeManager = ThemeManager()
    private let modelContainer: ModelContainer
    
    // Compute system serif fonts for nav bar titles using preferred text styles
    private static func serifUIFont(for textStyle: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        if let serif = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: serif, size: base.pointSize)
        }
        return base
    }
    init() {
        // Signpost: begin app startup interval
        Signpost.beginAppStartup()
        PerformanceMetricsService.shared.startSession()
        // Configure DI and register event handlers before any views initialize
        DIContainer.shared.configure()
        print("🚀 SonoraApp: DIContainer configured with shared services (App init)")
        
        // Build SwiftData container early and inject ModelContext into DI
        let schema = Schema([
            MemoModel.self,
            TranscriptionModel.self,
            AnalysisResultModel.self
        ])
        do {
            self.modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
        // Inject ModelContext for repositories/services
        DIContainer.shared.setModelContext(ModelContext(modelContainer))
        // Register event handlers now that persistence is ready
        DIContainer.shared.eventHandlerRegistry().registerAllHandlers()
        
        // Initialize onboarding configuration
        _ = OnboardingConfiguration.shared
        print("📋 SonoraApp: OnboardingConfiguration initialized (App init)")

        // Global Navigation Bar appearance: keep thin bottom divider (hairline)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.shadowColor = UIColor.separator // keep hairline
        // Apply system serif fonts (no bundled fonts) to navigation titles
        let largeTitleFont = Self.serifUIFont(for: .largeTitle)
        let titleFont = Self.serifUIFont(for: .headline)
        navAppearance.largeTitleTextAttributes = [ .font: largeTitleFont ]
        navAppearance.titleTextAttributes = [ .font: titleFont ]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance

        // Global Tab Bar appearance: add a hairline divider at top of tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundColor = UIColor.systemBackground
        tabAppearance.shadowColor = UIColor.separator
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Cloud transcription is now the only mode, so no additional model setup is required.
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .onAppear {
                    // Signpost: end app startup when first ContentView appears
                    Signpost.endAppStartup()
                    Signpost.event("ContentViewVisible")
                    PerformanceMetricsService.shared.recordStartupCompleted()
                }
                // Debug handler validation disabled by default (kept for manual testing)
                .onOpenURL { url in
                    print("🔗 SonoraApp: Deep link received: \(url)")
                    guard url.scheme == "sonora" else {
                        print("❌ SonoraApp: Invalid scheme: \(url.scheme ?? "nil")")
                        return
                    }

                    // Handle sonora://memo/<id>
                    if url.host == "memo" {
                        let idStr = url.lastPathComponent
                        if let id = UUID(uuidString: idStr) {
                            EventBus.shared.publish(.navigateOpenMemoByID(memoId: id))
                        } else {
                            print("⚠️ SonoraApp: Invalid memoId in deep link: \(idStr)")
                        }
                    } else if url.host == "open" {
                        // This is the new default action for tapping the Live Activity.
                        // It should just open the app, so no action is needed here.
                        print("✅ SonoraApp: App opened via Live Activity tap.")
                    } else {
                        print("⚠️ SonoraApp: Unknown or unhandled deep link host: \(url.host ?? "nil")")
                    }
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let idStr = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        print("🔍 Spotlight activity for memo: \(idStr)")
                        if let id = UUID(uuidString: idStr) {
                            EventBus.shared.publish(.navigateOpenMemoByID(memoId: id))
                        }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
