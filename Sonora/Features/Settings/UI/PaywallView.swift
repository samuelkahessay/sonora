import Combine
import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

@MainActor
final class PaywallViewModel: ObservableObject {
    enum Plan: String, CaseIterable { case monthly, annual }

    // Dependencies
    private let storeKitService: any StoreKitServiceProtocol

    // State
    @Published var isLoading: Bool = false
    @Published var selectedPlan: Plan = .monthly
    @Published var errorMessage: String?
    @Published var purchaseSuccessful: Bool = false

    init(storeKitService: any StoreKitServiceProtocol) {
        self.storeKitService = storeKitService
    }

    convenience init() {
        self.init(storeKitService: DIContainer.shared.storeKitService())
    }

    var isPro: Bool { storeKitService.isPro }

    func purchase() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let productId = selectedPlan == .monthly ? "sonora.pro.monthly" : "sonora.pro.annual"
        Task { @MainActor in
            do {
                let ok = try await storeKitService.purchase(productId: productId)
                if ok {
                    print("🛒 [Paywall] purchase succeeded for \(productId)")
                    purchaseSuccessful = true
                } else {
                    print("🛒 [Paywall] purchase returned false for \(productId)")
                    errorMessage = "Purchase failed or was cancelled."
                    purchaseSuccessful = false
                }
            } catch {
                print("🛒 [Paywall] purchase threw error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func restore() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let ok = try await storeKitService.restorePurchases()
                let final = ok || storeKitService.isPro
                print("🛒 [Paywall] restore result ok=\(ok) isPro=\(storeKitService.isPro) final=\(final)")
                if final {
                    purchaseSuccessful = true
                } else {
                    errorMessage = "No active purchases to restore."
                    purchaseSuccessful = false
                }
            } catch {
                print("🛒 [Paywall] restore threw error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct PaywallView: View {
    @SwiftUI.Environment(\.dismiss)
    private var dismiss
    @StateObject var viewModel = PaywallViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header
                planPicker
                benefits
                Spacer(minLength: 0)
                actions
                legal
            }
            .padding(24)
            .background(Color.semantic(.bgPrimary))
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay { if viewModel.isLoading { loadingOverlay } }
            .alert("Purchase Error", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.purchaseSuccessful) { _, ok in if ok { dismiss() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upgrade to Sonora Pro")
                .font(.title2.weight(.semibold))
                .foregroundColor(.semantic(.textPrimary))
            Text("Unlimited recording. Advanced insights. Turn your voice into action.")
                .font(.subheadline)
                .foregroundColor(.semantic(.textSecondary))
        }
    }

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Plan", selection: $viewModel.selectedPlan) {
                Text("$6.99/month").tag(PaywallViewModel.Plan.monthly)
                Text("$59.99/year • Save 29%")
                    .tag(PaywallViewModel.Plan.annual)
            }
            .pickerStyle(.segmented)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("Unlimited recording (remove 60 min/month limit)")
            benefitRow("Full Distill insights (vs. Lite Distill on Free)")
            benefitRow("Advanced analysis with patterns & connections across memos")
            benefitRow("Calendar event & reminder creation from your voice")
        }
        .padding(.top, 4)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.accentColor)
                .font(.body)
            Text(text)
                .foregroundColor(.semantic(.textPrimary))
                .font(.body)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: { viewModel.purchase() }) {
                Text(viewModel.selectedPlan == .monthly ? "Subscribe Now" : "Subscribe Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button("Restore Purchases") { viewModel.restore() }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

            #if DEBUG
            // Debug-only helper to force a local StoreKit purchase call for monthly
            Button("Debug Purchase Monthly") {
                Task { @MainActor in
                    print("🛒 [Paywall] Debug Purchase Monthly tapped")
                    let success = try? await DIContainer.shared.storeKitService().purchase(productId: "sonora.pro.monthly")
                    print("🔁 Debug purchase result:", success as Any)
                }
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)

            Button("Debug Fetch Products") {
                Task { @MainActor in
                    #if canImport(StoreKit)
                    let ids = ["sonora.pro.monthly", "sonora.pro.annual"]
                    do {
                        let products = try await Product.products(for: ids)
                        print("🛒 [Paywall] Debug fetch products:", products.map { $0.id }, "requested:", ids)
                    } catch {
                        print("🛒 [Paywall] Debug fetch products error:", error.localizedDescription)
                    }
                    #else
                    print("🛒 [Paywall] StoreKit not available for debug fetch")
                    #endif
                }
            }
            .buttonStyle(.bordered)

            HStack {
                Button("Force Pro (Debug ON)") {
                    let ud = UserDefaults.standard
                    ud.set(true, forKey: "storekit.isPro.cached")
                    ud.set(Date().timeIntervalSince1970, forKey: "storekit.isPro.cached.ts")
                    Task { await DIContainer.shared.storeKitService().refreshEntitlements() }
                    print("🛒 [Paywall] Forced Pro ON (debug)")
                }
                .buttonStyle(.borderedProminent)

                Button("Force Pro (Debug OFF)") {
                    let ud = UserDefaults.standard
                    ud.set(false, forKey: "storekit.isPro.cached")
                    ud.set(Date().timeIntervalSince1970, forKey: "storekit.isPro.cached.ts")
                    Task { await DIContainer.shared.storeKitService().refreshEntitlements() }
                    print("🛒 [Paywall] Forced Pro OFF (debug)")
                }
                .buttonStyle(.bordered)
            }
            #endif
        }
    }

    private var legal: some View {
        Text("Subscription auto-renews until cancelled. Manage or cancel in Settings. By subscribing, you agree to our Terms and Privacy Policy.")
            .font(.caption)
            .foregroundColor(.semantic(.textSecondary))
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.1).ignoresSafeArea()
            ProgressView().progressViewStyle(.circular)
        }
    }
}
