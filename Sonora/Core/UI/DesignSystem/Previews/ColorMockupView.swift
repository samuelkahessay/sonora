import SwiftUI

/// Comprehensive visual mockup showing all places where Sonora Mauve (#AD596C) is used throughout the app.
/// This file is for preview/testing only and does not affect the running app.
struct ColorMockupView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                // Header
                headerSection

                // NEW: Color Comparison Section
                newColorComparisonSection

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

            Text("Sonora Mauve (#AD596C) Implementation Preview")
                .font(.headline)
                .foregroundColor(.sonoraMauve)

            Text("Visual mockup of ALL changes that would be made")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.sonoraMauve.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - New Color Comparison

    private var newColorComparisonSection: some View {
        let currentMauve = Color(hexString: "#EB725C") // Old orange (pre-update)
        let proposedMauve = Color(hexString: "#AD596C") // New dusty rose mauve

        return VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 8) {
                Text("🆕 Proposed Color Update")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Comparing Current vs. Proposed Sonora Mauve")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Color swatches comparison
            HStack(spacing: 16) {
                // Current
                VStack(spacing: 12) {
                    Text("CURRENT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Rectangle()
                        .fill(currentMauve)
                        .frame(height: 100)
                        .cornerRadius(12)
                        .overlay(
                            Text("#EB725C")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        )

                    Text("RGB(235, 114, 92)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Orange/Halloween-y")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                    .font(.title2)

                // Proposed
                VStack(spacing: 12) {
                    Text("PROPOSED")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(proposedMauve)

                    Rectangle()
                        .fill(proposedMauve)
                        .frame(height: 100)
                        .cornerRadius(12)
                        .overlay(
                            Text("#AD596C")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        )

                    Text("RGB(173, 89, 108)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Dusty Rose/Mauve")
                        .font(.caption)
                        .foregroundColor(proposedMauve)
                }
            }

            Divider()

            // Live Activity Stop Button Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Live Activity Stop Button Preview")
                    .font(.headline)

                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("CURRENT")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Current: Growth Green
                        Text("Stop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hexString: "#4A9B8E")) // Growth Green
                            )

                        Text("Growth Green")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack(spacing: 8) {
                        Text("PROPOSED")
                            .font(.caption)
                            .foregroundColor(proposedMauve)

                        // Proposed: New Mauve
                        Text("Stop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(proposedMauve)
                            )

                        Text("Sonora Mauve")
                            .font(.caption2)
                            .foregroundColor(proposedMauve)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }

            // UI Examples with new color
            VStack(alignment: .leading, spacing: 12) {
                Text("UI Examples with Proposed Color")
                    .font(.headline)

                // Play button example
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Play Button")
                            .font(.caption)
                        Button(action: {}) {
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(proposedMauve)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 8) {
                        Text("Background Tint")
                            .font(.caption)
                        Rectangle()
                            .fill(proposedMauve.opacity(0.1))
                            .frame(width: 80, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                Text("10%")
                                    .font(.caption2)
                                    .foregroundColor(proposedMauve)
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Secondary Text")
                            .font(.caption)
                        Text("Sample")
                            .foregroundColor(proposedMauve.opacity(0.6))
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(proposedMauve.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(proposedMauve, lineWidth: 2)
        )
    }

    // MARK: - Decision Summary

    private var decisionSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Selected Color: Sonora Mauve")
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
                .stroke(Color.sonoraMauve, lineWidth: 2)
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

                // Proposed (Mauve)
                VStack(spacing: 12) {
                    Text("WITH SONORA MAUVE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.sonoraMauve)

                    fullAudioControlsMockup(
                        buttonColor: .sonoraMauve,
                        label: "Sonora Mauve"
                    )
                }
            }

            changeNote(
                token: "Color.semantic(.brandPrimary)",
                change: ".systemBlue → .sonoraMauve (#EB725C)"
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
                        .foregroundColor(.sonoraMauve)

                    onboardingMockup(accentColor: .sonoraMauve)
                }
            }

            changeNote(
                token: ".tint(.blue) & .foregroundStyle(.blue.gradient)",
                change: "Replace with .sonoraMauve gradient"
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

            Text("Light blue backgrounds replaced with light mauve tints")
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
                        .foregroundColor(.sonoraMauve)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed: Mauve Tint")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.sonoraMauve)

                        Rectangle()
                            .fill(Color.sonoraMauve.opacity(0.1))
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
                change: "Replace with Color.sonoraMauve.opacity(0.1)"
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

            Text("Blue-gray secondary text replaced with mauve-based gray")
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
                        .foregroundColor(.sonoraMauve)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Proposed: Mauve-based")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.sonoraMauve)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Primary Text")
                                .foregroundColor(.primary)
                            Text("Secondary Text with warm undertone")
                                .font(.caption)
                                .foregroundColor(Color.sonoraMauve.opacity(0.6))
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)

                        Text("sonoraMauve @ 60% opacity")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            changeNote(
                token: "Color.reflectionGray",
                change: "Replace with Color.sonoraMauve.opacity(0.6)"
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
                            .foregroundColor(.sonoraMauve)
                        Slider(value: .constant(0.6), in: 0...1)
                            .tint(.sonoraMauve)
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
                            .foregroundColor(.sonoraMauve)
                        ProgressView(value: 0.7)
                            .tint(.sonoraMauve)
                    }
                }

                // Buttons
                HStack(spacing: 12) {
                    Button("Action") {}
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                    Button("Action") {}
                        .buttonStyle(.borderedProminent)
                        .tint(.sonoraMauve)
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
                    detail: "brandPrimary fallback: .systemBlue → Custom Mauve asset"
                )

                changeItem(
                    number: "2",
                    title: "Update SonoraBrandColors.swift",
                    detail: "Remove whisperBlue & reflectionGray, add mauve tint utilities"
                )

                changeItem(
                    number: "3",
                    title: "Replace Direct Blue Usage",
                    detail: "Onboarding files: .blue → .sonoraMauve (2 files)"
                )

                changeItem(
                    number: "4",
                    title: "Replace whisperBlue",
                    detail: "7 files: Replace with sonoraMauve.opacity(0.1)"
                )

                changeItem(
                    number: "5",
                    title: "Replace reflectionGray",
                    detail: "7 files: Replace with sonoraMauve.opacity(0.6)"
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
        .background(Color.sonoraMauve.opacity(0.05))
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
                .foregroundColor(.sonoraMauve)
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
                .background(Color.sonoraMauve)
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
