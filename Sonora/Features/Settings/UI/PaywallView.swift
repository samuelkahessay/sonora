import SwiftUI
import Combine

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
        let productId = selectedPlan == .monthly ? "pro.monthly" : "pro.annual"
        Task { @MainActor in
            do {
                let ok = try await storeKitService.purchase(productId: productId)
                purchaseSuccessful = ok
            } catch {
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
                purchaseSuccessful = ok || storeKitService.isPro
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct PaywallView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
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
            Text("Clarity without limits. Deeper insights when you’re ready.")
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
            benefitRow("Advanced AI analysis (Themes, Todos, Content)")
            benefitRow("Calendar & Reminder creation")
            benefitRow("Premium export options")
        }
        .padding(.top, 4)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.semantic(.brandPrimary))
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
