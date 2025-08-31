//
//  SonoraApp.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI
import UIKit
import CoreSpotlight

@main
struct SonoraApp: App {
    @StateObject private var themeManager = ThemeManager()
    init() {
        // Configure DI and register event handlers before any views initialize
        DIContainer.shared.configure()
        print("🚀 SonoraApp: DIContainer configured with shared services (App init)")
        DIContainer.shared.eventHandlerRegistry().registerAllHandlers()
        print("🎯 SonoraApp: Event handlers registered (App init)")
        
        // Initialize onboarding configuration
        _ = OnboardingConfiguration.shared
        print("📋 SonoraApp: OnboardingConfiguration initialized (App init)")

        // Global Navigation Bar appearance: ensure clear bottom divider (hairline) visible across app
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.shadowColor = UIColor.separator
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

                    // Accept both sonora://stopRecording and sonora:/stopRecording formats
                    let isStopLink: Bool = {
                        if url.host == "stopRecording" { return true }
                        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        return path == "stopRecording"
                    }()
                    if isStopLink == false {
                        print("ℹ️ SonoraApp: Deep link not matched as stop (host=\(url.host ?? "nil"), path=\(url.path))")
                    }

                    if isStopLink {
                        print("🎯 SonoraApp: Processing stop recording deep link")
                        Task { @MainActor in
                            do {
                                // Attempt to stop the current recording operation gracefully
                                let coordinator = DIContainer.shared.operationCoordinator()
                                let activeOps = await coordinator.getAllActiveOperations()
                                print("📊 SonoraApp: Found \(activeOps.count) active operations")
                                
                                if let recordingOp = activeOps.first(where: { $0.type.category == .recording }) {
                                    print("🎤 SonoraApp: Found active recording operation for memo: \(recordingOp.type.memoId)")
                                    let memoId = recordingOp.type.memoId
                                    let audioRepo = DIContainer.shared.audioRepository()
                                    let stopUseCase = StopRecordingUseCase(
                                        audioRepository: audioRepo,
                                        operationCoordinator: DIContainer.shared.operationCoordinator()
                                    )
                                    
                                    do {
                                        try await stopUseCase.execute(memoId: memoId)
                                        print("✅ SonoraApp: Successfully stopped recording via deep link")
                                    } catch {
                                        print("❌ SonoraApp: Failed to stop recording via deep link: \(error)")
                                    }
                                } else {
                                    print("⚠️ SonoraApp: No active recording operation found")
                                }
                                
                                // End the live activity immediately so it disappears right away
                                print("🔄 SonoraApp: Ending Live Activity...")
                                let liveService = DIContainer.shared.liveActivityService()
                                let endUseCase = EndLiveActivityUseCase(liveActivityService: liveService)
                                
                                try await endUseCase.execute(dismissalPolicy: .immediate)
                                print("✅ SonoraApp: Successfully ended Live Activity")
                                
                            } catch {
                                print("❌ SonoraApp: Deep link handling failed: \(error)")
                            }
                        }
                    } else {
                        // Handle sonora://memo/<id>
                        if url.host == "memo" {
                            let idStr = url.lastPathComponent
                            NotificationCenter.default.post(name: .openMemoByID, object: nil, userInfo: ["memoId": idStr])
                        } else {
                            print("❌ SonoraApp: Unknown deep link host: \(url.host ?? "nil")")
                        }
                    }
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let idStr = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        print("🔍 Spotlight activity for memo: \(idStr)")
                        NotificationCenter.default.post(name: .openMemoByID, object: nil, userInfo: ["memoId": idStr])
                    }
                }
        }
    }
}
