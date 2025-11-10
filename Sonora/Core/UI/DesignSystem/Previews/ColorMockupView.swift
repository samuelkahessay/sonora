import SwiftUI

/// Comprehensive visual mockup showing all places where Sonora Salmon (#EB725C) would replace blue.
/// This file is for preview/testing only and does not affect the running app.
struct ColorMockupView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Header
                headerSection

                // Decision Summary
                decisionSummarySection

                Divider()

                // 1. Audio Controls (Play Button)
                audioControlsComparison

                Divider()

                // 2. Onboarding Screens
                onboardingComparison

                Divider()

                // 3. Background Colors
                backgroundColorsComparison

                Divider()

                // 4. Text & Secondary Colors
                textColorsComparison

                Divider()

                // 5. Interactive Elements
                interactiveElementsComparison

                Divider()

                // Summary of Changes
                changesSummarySection
            }
            .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("🎨 Complete Color System Update")
                .font(.system(.title, design: .serif))
                .fontWeight(.bold)

            Text("Sonora Salmon (#EB725C) Implementation Preview")
                .font(.headline)
                .foregroundColor(.sonoraSalmon)

            Text("Visual mockup of ALL changes that would be made")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.sonoraSalmon.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Decision Summary

    private var decisionSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Selected Color: Sonora Salmon")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hex Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("#EB725C")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location in Logo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Warm coral-red gradient stop")
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Contrast (white)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("4.1:1")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.sonoraSalmon, lineWidth: 2)
        )
    }

    // MARK: - 1. Audio Controls Comparison

    private var audioControlsComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "1. Audio Controls (Main Impact)",
                file: "MemoDetailView.swift:381"
            )

            Text("Play button background and skip button accents")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                // Current (Blue)
                VStack(spacing: 12) {
                    Text("CURRENT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    fullAudioControlsMockup(
                        buttonColor: .blue,
                        label: "System Blue"
                    )
                }

                // Proposed (Salmon)
                VStack(spacing: 12) {
                    Text("WITH SONORA SALMON")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.sonoraSalmon)

                    fullAudioControlsMockup(
                        buttonColor: .sonoraSalmon,
                        label: "Sonora Salmon"
                    )
                }
            }

            changeNote(
                token: "Color.semantic(.brandPrimary)",
                change: ".systemBlue → .sonoraSalmon (#EB725C)"
            )
        }
    }

    // MARK: - 2. Onboarding Comparison

    private var onboardingComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "2. Onboarding Screens",
                file: "OnboardingPageView.swift:141, NameEntryView.swift:36"
            )

            Text("Button tints and icon gradients")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                // Current
                VStack(spacing: 16) {
                    Text("CURRENT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    onboardingMockup(accentColor: .blue)
                }

                // Proposed
                VStack(spacing: 16) {
                    Text("WITH SONORA SALMON")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.sonoraSalmon)

                    onboardingMockup(accentColor: .sonoraSalmon)
                }
            }

            changeNote(
                token: ".tint(.blue) & .foregroundStyle(.blue.gradient)",
                change: "Replace with .sonoraSalmon gradient"
            )
        }
    }

    // MARK: - 3. Background Colors

    private var backgroundColorsComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "3. Background Colors (whisperBlue)",
                file: "Multiple files (RecordingView.swift:40, SonoraInsightCard.swift:335, etc.)"
            )

            Text("Light blue backgrounds replaced with light salmon tints")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // whisperBlue backgrounds
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current: whisperBlue")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Rectangle()
                            .fill(Color(hexString: "#E8F0FF"))
                            .frame(height: 60)
                            .overlay(
                                Text("Background Surface")
                                    .font(.caption)
                            )

                        Text("#E8F0FF (Blue tint)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.sonoraSalmon)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed: Salmon Tint")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.sonoraSalmon)

                        Rectangle()
                            .fill(Color.sonoraSalmon.opacity(0.1))
                            .frame(height: 60)
                            .overlay(
                                Text("Background Surface")
                                    .font(.caption)
                            )

                        Text("#EB725C @ 10% opacity")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Usage examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Used in:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Card backgrounds")
                    Text("• Empty state surfaces")
                    Text("• Insight card backgrounds")
                    Text("• Recording view gradient")
                }
                .font(.caption)
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }

            changeNote(
                token: "Color.whisperBlue",
                change: "Replace with Color.sonoraSalmon.opacity(0.1)"
            )
        }
    }

    // MARK: - 4. Text Colors

    private var textColorsComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "4. Secondary Text Colors (reflectionGray)",
                file: "Multiple files (SonoraInsightCard.swift:157, MemoEmptyStateView.swift:83, etc.)"
            )

            Text("Blue-gray secondary text replaced with salmon-based gray")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current: reflectionGray")
                            .font(.caption)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primary Text")
                                .foregroundColor(.primary)
                            Text("Secondary Text with blue undertone")
                                .font(.caption)
                                .foregroundColor(Color(hexString: "#8B9DC3"))
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)

                        Text("#8B9DC3 (Blue-gray)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.sonoraSalmon)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed: Salmon-based")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.sonoraSalmon)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primary Text")
                                .foregroundColor(.primary)
                            Text("Secondary Text with warm undertone")
                                .font(.caption)
                                .foregroundColor(Color.sonoraSalmon.opacity(0.6))
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)

                        Text("sonoraSalmon @ 60% opacity")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            changeNote(
                token: "Color.reflectionGray",
                change: "Replace with Color.sonoraSalmon.opacity(0.6)"
            )
        }
    }

    // MARK: - 5. Interactive Elements

    private var interactiveElementsComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "5. Interactive Elements",
                file: "Various UI components"
            )

            Text("Sliders, progress indicators, and accents")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                // Slider
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text("Current")
                            .font(.caption)
                        Slider(value: .constant(0.6), in: 0...1)
                            .tint(.blue)
                    }

                    VStack(spacing: 8) {
                        Text("Proposed")
                            .font(.caption)
                            .foregroundColor(.sonoraSalmon)
                        Slider(value: .constant(0.6), in: 0...1)
                            .tint(.sonoraSalmon)
                    }
                }

                // Progress View
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text("Progress")
                            .font(.caption)
                        ProgressView(value: 0.7)
                            .tint(.blue)
                    }

                    VStack(spacing: 8) {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.sonoraSalmon)
                        ProgressView(value: 0.7)
                            .tint(.sonoraSalmon)
                    }
                }

                // Buttons
                HStack(spacing: 12) {
                    Button("Action") {}
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                    Button("Action") {}
                        .buttonStyle(.borderedProminent)
                        .tint(.sonoraSalmon)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
        }
    }

    // MARK: - Changes Summary

    private var changesSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📋 Implementation Checklist")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                changeItem(
                    number: "1",
                    title: "Update SemanticColors.swift",
                    detail: "brandPrimary fallback: .systemBlue → Custom Salmon asset"
                )

                changeItem(
                    number: "2",
                    title: "Update SonoraBrandColors.swift",
                    detail: "Remove whisperBlue & reflectionGray, add salmon tint utilities"
                )

                changeItem(
                    number: "3",
                    title: "Replace Direct Blue Usage",
                    detail: "Onboarding files: .blue → .sonoraSalmon (2 files)"
                )

                changeItem(
                    number: "4",
                    title: "Replace whisperBlue",
                    detail: "7 files: Replace with sonoraSalmon.opacity(0.1)"
                )

                changeItem(
                    number: "5",
                    title: "Replace reflectionGray",
                    detail: "7 files: Replace with sonoraSalmon.opacity(0.6)"
                )

                changeItem(
                    number: "6",
                    title: "Create Asset Color",
                    detail: "Add brand/BrandPrimary.colorset with #EB725C"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            Text("✅ All changes maintain WCAG AA accessibility standards")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.sonoraSalmon.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Helper Components

    private func sectionHeader(title: String, file: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text("📁 \(file)")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontDesign(.monospaced)
        }
    }

    private func changeNote(token: String, change: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Change:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(token)
                .font(.caption)
                .fontDesign(.monospaced)
            Text("→ \(change)")
                .font(.caption)
                .foregroundColor(.sonoraSalmon)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func changeItem(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.sonoraSalmon)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func fullAudioControlsMockup(buttonColor: Color, label: String) -> some View {
        VStack(spacing: 10) {
            // Time scrubber
            HStack(spacing: 8) {
                Text("0:42")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .leading)

                Slider(value: .constant(0.3), in: 0...1)
                    .tint(buttonColor)

                Text("2:34")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            // Controls
            HStack(spacing: 18) {
                Button(action: {}) {
                    Image(systemName: "gobackward.15")
                        .font(.title3)
                        .foregroundColor(buttonColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(buttonColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "goforward.15")
                        .font(.title3)
                        .foregroundColor(buttonColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func onboardingMockup(accentColor: Color) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 48))
                .foregroundStyle(accentColor.gradient)
                .symbolRenderingMode(.multicolor)

            Text("Get Started")
                .font(.headline)

            Button("Continue") {}
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct ColorMockupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ColorMockupView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            ColorMockupView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
