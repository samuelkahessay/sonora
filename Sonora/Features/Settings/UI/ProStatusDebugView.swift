import RevenueCat
import SwiftUI

/// Comprehensive debug view for Pro subscription status and RevenueCat integration.
/// Shows all internal state to help diagnose entitlement issues in TestFlight.
struct ProStatusDebugView: View {
    @SwiftUI.Environment(\.diContainer) private var container: DIContainer
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    @State private var refreshError: String?
    @State private var customerInfo: CustomerInfo?
    @State private var offerings: Offerings?

    // Current Pro status from service
    private var storeService: any StoreKitServiceProtocol {
        container.storeKitService()
    }

    var body: some View {
        List {
            // MARK: - Current Status Section
            Section {
                StatusRow(title: "Pro Status", value: storeService.isPro ? "✅ Active" : "❌ Not Active")
                    .foregroundColor(storeService.isPro ? .green : .red)
                    .font(.headline)
            } header: {
                Text("Current Status")
            }

            // MARK: - Configuration Section
            Section {
                ConfigRow(title: "API Key", value: maskedApiKey)
                ConfigRow(title: "Entitlement ID", value: entitlementId)
                ConfigRow(title: "Environment", value: environmentInfo)
                ConfigRow(title: "User ID", value: customerInfo?.originalAppUserId ?? "Unknown")
            } header: {
                Text("RevenueCat Configuration")
            } footer: {
                Text("The entitlement ID must match exactly (case-sensitive) with what's configured in your RevenueCat dashboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - Cache Section
            Section {
                if let cacheInfo = getCacheInfo() {
                    ConfigRow(title: "Cached Value", value: cacheInfo.value ? "Pro" : "Free")
                    ConfigRow(title: "Cache Age", value: cacheInfo.age)
                    ConfigRow(title: "Cache Valid", value: cacheInfo.isValid ? "Yes" : "No (expired)")
                } else {
                    Text("No cached data")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Cache Status (TTL: 1 hour)")
            }

            // MARK: - Entitlements Section
            Section {
                if let info = customerInfo {
                    if info.entitlements.active.isEmpty {
                        Text("No active entitlements")
                            .foregroundColor(.orange)
                            .italic()
                    } else {
                        ForEach(Array(info.entitlements.active.keys.sorted()), id: \.self) { key in
                            if let entitlement = info.entitlements.active[key] {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entitlement.identifier)
                                        .font(.headline)
                                        .foregroundColor(.green)

                                    HStack {
                                        Label("Active", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)

                                        if let expiry = entitlement.expirationDate {
                                            Text("Expires: \(expiry, style: .relative)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Text("Product: \(entitlement.productIdentifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Show all entitlements (including inactive)
                    if !info.entitlements.all.isEmpty {
                        DisclosureGroup("All Entitlements (\(info.entitlements.all.count))") {
                            ForEach(Array(info.entitlements.all.keys.sorted()), id: \.self) { key in
                                if let entitlement = info.entitlements.all[key] {
                                    HStack {
                                        Text(entitlement.identifier)
                                            .font(.caption)
                                        Spacer()
                                        Text(entitlement.isActive ? "Active" : "Inactive")
                                            .font(.caption)
                                            .foregroundColor(entitlement.isActive ? .green : .secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("Loading entitlements...")
                        .foregroundColor(.secondary)
                        .italic()
                }
            } header: {
                Text("Active Entitlements from RevenueCat")
            } footer: {
                if let info = customerInfo, info.entitlements.active.isEmpty {
                    Text("⚠️ No active entitlements found. Make sure your sandbox tester has an active subscription in RevenueCat dashboard and that the entitlement identifier matches '\(entitlementId)'.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // MARK: - Available Products Section
            Section {
                if let offerings = offerings {
                    if let current = offerings.current {
                        Text("Current Offering: \(current.identifier)")
                            .font(.headline)

                        ForEach(current.availablePackages, id: \.identifier) { package in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(package.identifier)
                                    .font(.subheadline)
                                Text("Product: \(package.storeProduct.productIdentifier)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Price: \(package.localizedPriceString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        Text("No current offering configured")
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Loading offerings...")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Available Products")
            }

            // MARK: - Last Refresh Section
            Section {
                if let time = lastRefreshTime {
                    Text("Last refresh: \(time, style: .relative)")
                        .font(.caption)
                } else {
                    Text("Not refreshed yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = refreshError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    Task { await forceRefresh() }
                } label: {
                    HStack {
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Refreshing...")
                        } else {
                            Label("Force Refresh Entitlements", systemImage: "arrow.clockwise")
                        }
                        Spacer()
                    }
                }
                .disabled(isRefreshing)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } header: {
                Text("Actions")
            } footer: {
                Text("Force refresh will fetch the latest entitlement status from RevenueCat servers, bypassing the cache.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - Diagnostics Section
            Section {
                DiagnosticRow(
                    icon: "checkmark.circle.fill",
                    iconColor: storeService.isPro ? .green : .red,
                    title: "Pro Status Check",
                    message: storeService.isPro
                        ? "Pro features should be visible"
                        : "Pro features will be hidden"
                )

                if let info = customerInfo {
                    let hasExpectedEntitlement = info.entitlements[entitlementId] != nil
                    DiagnosticRow(
                        icon: hasExpectedEntitlement ? "checkmark.circle.fill" : "xmark.circle.fill",
                        iconColor: hasExpectedEntitlement ? .green : .orange,
                        title: "Entitlement '\(entitlementId)' Found",
                        message: hasExpectedEntitlement
                            ? "The expected entitlement exists"
                            : "Entitlement not found - check dashboard configuration"
                    )

                    let hasAnyActive = !info.entitlements.active.isEmpty
                    DiagnosticRow(
                        icon: hasAnyActive ? "checkmark.circle.fill" : "xmark.circle.fill",
                        iconColor: hasAnyActive ? .green : .orange,
                        title: "Any Active Entitlement",
                        message: hasAnyActive
                            ? "Fallback logic can activate Pro"
                            : "No active entitlements at all"
                    )
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("""
                The app checks for the '\(entitlementId)' entitlement first. If not found, it falls back to checking if ANY entitlement is active. Both must fail for Pro to be disabled.
                """)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Pro Subscription Status")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadInitialData()
        }
    }

    // MARK: - Helpers

    private var maskedApiKey: String {
        // Try to get the API key from RevenueCat service
        // Since we can't access it directly, we'll show what we know
        if let envKey = ProcessInfo.processInfo.environment["RC_API_KEY"] {
            return maskKey(envKey)
        }
        return maskKey("appl_NuJfLSURCFnBBqcYSlHIwfYreue") // Default key
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 4 else { return "****" }
        let suffix = key.suffix(4)
        return String(repeating: "*", count: key.count - 4) + suffix
    }

    private var entitlementId: String {
        ProcessInfo.processInfo.environment["RC_ENTITLEMENT_ID"] ?? "pro"
    }

    private var environmentInfo: String {
        let isTestFlight = Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
        let isDebug = _isDebugAssertConfiguration()

        if isTestFlight {
            return "TestFlight (Sandbox)"
        } else if isDebug {
            return "Debug (Simulator)"
        } else {
            return "Production"
        }
    }

    private func getCacheInfo() -> (value: Bool, age: String, isValid: Bool)? {
        let userDefaults = UserDefaults.standard
        guard let cached = userDefaults.object(forKey: "storekit.isPro.cached") as? Bool,
              let timestamp = userDefaults.object(forKey: "storekit.isPro.cached.ts") as? TimeInterval else {
            return nil
        }

        let now = Date().timeIntervalSince1970
        let age = now - timestamp
        let isValid = age < 3_600 // 1 hour TTL

        let ageString: String
        if age < 60 {
            ageString = "\(Int(age))s ago"
        } else if age < 3_600 {
            ageString = "\(Int(age / 60))m ago"
        } else {
            ageString = "\(Int(age / 3_600))h ago"
        }

        return (cached, ageString, isValid)
    }

    private func loadInitialData() async {
        do {
            // Fetch current customer info
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.customerInfo = info
            }

            // Fetch offerings
            let offers = try await Purchases.shared.offerings()
            await MainActor.run {
                self.offerings = offers
            }
        } catch {
            await MainActor.run {
                self.refreshError = error.localizedDescription
            }
        }
    }

    private func forceRefresh() async {
        await MainActor.run {
            isRefreshing = true
            refreshError = nil
        }

        do {
            // Force refresh entitlements
            await storeService.refreshEntitlements(force: true)

            // Fetch fresh customer info
            let info = try await Purchases.shared.customerInfo()

            await MainActor.run {
                self.customerInfo = info
                self.lastRefreshTime = Date()
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                self.refreshError = error.localizedDescription
                self.lastRefreshTime = Date()
                self.isRefreshing = false
            }
        }
    }
}

// MARK: - Supporting Views

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

private struct ConfigRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}

private struct DiagnosticRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ProStatusDebugView()
            .withDIContainer()
    }
}
