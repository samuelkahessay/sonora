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
    init() {
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
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

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
                // Optional debug validation of handlers
                #if DEBUG
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        DIContainer.shared.eventHandlerRegistry().testEventFlow()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("🔍 Event Handler Status:")
                            print(DIContainer.shared.eventHandlerRegistry().detailedStatus)
                            if let memoHandler = DIContainer.shared.eventHandlerRegistry().getHandler("MemoEventHandler", as: MemoEventHandler.self) {
                                print("📊 MemoEventHandler Statistics:")
                                print(memoHandler.handlerStatistics)
                            }
                        }
                    }
                }
                #endif
                .onOpenURL { url in
                    print("🔗 SonoraApp: Deep link received: \(url)")
                    guard url.scheme == "sonora" else {
                        print("❌ SonoraApp: Invalid scheme: \(url.scheme ?? "nil")")
                        return
                    }

                    // Handle sonora://memo/<id>
                    if url.host == "memo" {
                        let idStr = url.lastPathComponent
                        NotificationCenter.default.post(name: .openMemoByID, object: nil, userInfo: ["memoId": idStr])
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
                        NotificationCenter.default.post(name: .openMemoByID, object: nil, userInfo: ["memoId": idStr])
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
