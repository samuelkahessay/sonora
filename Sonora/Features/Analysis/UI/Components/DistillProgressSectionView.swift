import SwiftUI

internal struct DistillProgressSectionView: View {
    let progress: DistillProgressUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.subheadline)
                    .foregroundColor(.semantic(.brandPrimary))
                Text("Processing Components (\(progress.completedComponents)/\(progress.totalComponents))")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let latestComponent = progress.latestComponent {
                    Text(latestComponent.displayName)
                        .font(.caption)
                        .foregroundColor(.semantic(.success))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.semantic(.success).opacity(0.1))
                        .cornerRadius(4)
                }
            }

            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .semantic(.brandPrimary)))
        }
        .padding(12)
        .background(Color.semantic(.brandPrimary).opacity(0.05))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: progress.completedComponents)
    }
}
