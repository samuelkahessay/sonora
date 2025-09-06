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
    
    // Prefer New York serif; gracefully fall back to a system serif design
    private static func findNewYorkFont(size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        // Candidate PostScript names observed on iOS (New York comes in Large/Medium/Small families)
        let candidates = [
            // Semibold/Bold options first for titles
            "NewYorkLarge-Semibold", "NewYorkMedium-Semibold", "NewYorkSmall-Semibold",
            "NewYorkLarge-Bold", "NewYorkMedium-Bold", "NewYorkSmall-Bold",
            // Medium/Regular fallbacks
            "NewYork-Medium", "NewYork-Regular",
            // Family name (may resolve on some systems)
            "New York"
        ]
        for name in candidates {
            if let f = UIFont(name: name, size: size) { return f }
        }
        // Serif system fallback at requested size
        let base = UIFont.preferredFont(forTextStyle: textStyle)
        if let serif = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: serif, size: size)
        }
        return base
    }
    init() {
        // Signpost: begin app startup interval
        Signpost.beginAppStartup()
        // Configure DI and register event handlers before any views initialize
        DIContainer.shared.configure()
        print("🚀 SonoraApp: DIContainer configured with shared services (App init)")
        
        #if DEBUG
        // Debug: Print ALL available fonts to find New York variants
        print("🔤 All Available Fonts:")
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                if name.lowercased().contains("new york") || name.lowercased().contains("newyork") {
                    print("   ★ \(name) ← New York font found!")
                } else {
                    print("   \(name)")
                }
            }
        }
        #endif
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
        // Apply New York serif font to navigation titles with robust fallbacks
        let largeTitleFont = Self.findNewYorkFont(size: 34, textStyle: .largeTitle)
        let titleFont = Self.findNewYorkFont(size: 17, textStyle: .headline)
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

        // Hint Hugging Face to disable telemetry writes that create analytics files
        setenv("HF_HUB_DISABLE_TELEMETRY", "1", 1)
        setenv("HUGGINGFACE_HUB_DISABLE_TELEMETRY", "1", 1)

        // Pre-create common HuggingFace directories used by WhisperKit downloads on iOS
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let hfBaseDocs = docs.appendingPathComponent("huggingface", isDirectory: true)
        let hfAnalyticsDocs = hfBaseDocs.appendingPathComponent("analytics", isDirectory: true)
        let hfModelsDocs = hfBaseDocs.appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
        let hfBaseCaches = caches.appendingPathComponent("huggingface", isDirectory: true)
        let hfAnalyticsCaches = hfBaseCaches.appendingPathComponent("analytics", isDirectory: true)
        try? fm.createDirectory(at: hfBaseDocs, withIntermediateDirectories: true)
        try? fm.createDirectory(at: hfAnalyticsDocs, withIntermediateDirectories: true)
        try? fm.createDirectory(at: hfModelsDocs, withIntermediateDirectories: true)
        try? fm.createDirectory(at: hfBaseCaches, withIntermediateDirectories: true)
        try? fm.createDirectory(at: hfAnalyticsCaches, withIntermediateDirectories: true)

        // Point HF_HOME to a deterministic app-local path like Whisperboard
        setenv("HF_HOME", hfBaseDocs.path, 1)
        setenv("TRANSFORMERS_CACHE", hfBaseDocs.path, 1)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorSchemeOverride)
                .onAppear {
                    // Signpost: end app startup when first ContentView appears
                    Signpost.endAppStartup()
                    Signpost.event("ContentViewVisible")
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
