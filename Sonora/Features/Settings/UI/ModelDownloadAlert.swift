import SwiftUI

struct ModelDownloadAlert: View {
    let title: String
    let modelName: String
    let sizeText: String
    let availableText: String?
    let wifiRequired: Bool
    let descriptionText: String
    let onDownloadNow: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(modelName)", systemImage: "cpu")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))

                HStack(spacing: 12) {
                    Label("Size: \(sizeText)", systemImage: "shippingbox")
                    if let availableText { Label("Available: \(availableText)", systemImage: "iphone") }
                }
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))

                if wifiRequired {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.exclamationmark").foregroundColor(.semantic(.warning))
                        Text("Wi‑Fi required for download")
                            .font(.caption)
                            .foregroundColor(.semantic(.warning))
                    }
                }

                Text(descriptionText)
                    .font(.caption)
                    .foregroundColor(.semantic(.textSecondary))
                    .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button("Later") { onLater() }
                    .buttonStyle(.bordered)
                Button("Download Now") { onDownloadNow() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.semantic(.fillSecondary))
        )
        .padding()
    }
}

