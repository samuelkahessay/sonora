//
//  MemosView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

extension Notification.Name {
    static let popToRootMemos = Notification.Name("popToRootMemos")
}

struct MemosView: View {
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var viewModel = MemoListViewModel()
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack {
                // Beautiful glass background for memos
                LinearGradient(
                    colors: [
                        Color.teal.opacity(0.08),
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                Group {
                    if viewModel.isEmpty {
                        VStack(spacing: 24) {
                            // Glass icon container
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .fill(theme.activeTheme.palette.backgroundGlass)
                                    }
                                    .overlay {
                                        Circle()
                                            .strokeBorder(theme.activeTheme.palette.glassBorder, lineWidth: 1)
                                    }
                                    .frame(width: 100, height: 100)
                                    .shadow(color: theme.activeTheme.palette.glassShadow, radius: 15, x: 0, y: 8)
                                
                                Image(systemName: viewModel.emptyStateIcon)
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [theme.activeTheme.palette.secondary, theme.activeTheme.palette.primary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .shimmerEffect(palette: theme.activeTheme.palette)
                            
                            VStack(spacing: 12) {
                                Text(viewModel.emptyStateTitle)
                                    .glassTextStyle(.title2, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                    .foregroundStyle(theme.activeTheme.palette.textOnGlass)
                                
                                Text(viewModel.emptyStateSubtitle)
                                    .glassTextStyle(.body, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                                    .foregroundColor(theme.activeTheme.palette.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frostedGlassCard(palette: theme.activeTheme.palette, elevation: .medium)
                        .padding(.horizontal, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.memos) { memo in
                                    NavigationLink(value: memo) {
                                        MemoRowView(memo: memo, viewModel: viewModel)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .refreshable {
                            viewModel.refreshMemos()
                        }
                    }
                }
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.loadMemos()
                    }
                    .foregroundStyle(theme.activeTheme.palette.primary)
                    .fontWeight(.medium)
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            viewModel.onViewAppear()
        }
    }
    
}

struct MemoRowView: View {
    @EnvironmentObject private var theme: ThemeManager
    let memo: Memo
    let viewModel: MemoListViewModel
    @State private var transcriptionState: TranscriptionState = .notStarted
    
    var body: some View {
        VStack(spacing: 12) {
            // Main content row
            HStack(spacing: 16) {
                // Play button with glass styling
                Button(action: {
                    viewModel.playMemo(memo)
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .fill(theme.activeTheme.palette.backgroundGlass)
                            }
                            .frame(width: 50, height: 50)
                            .overlay {
                                Circle()
                                    .strokeBorder(theme.activeTheme.palette.glassBorder, lineWidth: 0.8)
                            }
                            .shadow(color: theme.activeTheme.palette.glassShadow, radius: 8, x: 0, y: 4)
                        
                        Image(systemName: viewModel.playButtonIcon(for: memo))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [theme.activeTheme.palette.primary, theme.activeTheme.palette.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Memo information
                VStack(alignment: .leading, spacing: 6) {
                    Text(memo.displayName)
                        .glassTextStyle(.headline, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                        .foregroundStyle(theme.activeTheme.palette.textOnGlass)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(memo.filename)
                            .glassTextStyle(.caption, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                            .foregroundColor(theme.activeTheme.palette.textSecondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(memo.durationString)
                            .glassTextStyle(.caption, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                            .foregroundColor(theme.activeTheme.palette.textSecondary)
                            .monospacedDigit()
                    }
                }
                
                Spacer(minLength: 8)
            }
            
            // Transcription status section
            HStack {
                TranscriptionStatusView(state: transcriptionState, compact: true)
                
                Spacer()
                
                // Action buttons with glass styling
                if transcriptionState.isFailed {
                    Button("Retry") {
                        viewModel.retryTranscription(for: memo)
                    }
                    .glassTextStyle(.caption, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [theme.activeTheme.palette.warning, theme.activeTheme.palette.warning.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                    }
                } else if transcriptionState.isInProgress {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.activeTheme.palette.primary))
                            .scaleEffect(0.8)
                        
                        Text("Processing...")
                            .glassTextStyle(.caption, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                            .foregroundColor(theme.activeTheme.palette.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(theme.activeTheme.palette.primary.opacity(0.1))
                            }
                    }
                } else if transcriptionState.isNotStarted {
                    Button("Transcribe") {
                        viewModel.startTranscription(for: memo)
                    }
                    .glassTextStyle(.caption, typography: theme.effectiveTypography, palette: theme.activeTheme.palette)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(theme.activeTheme.palette.primaryGradient)
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.activeTheme.palette.backgroundGlass)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(theme.activeTheme.palette.glassBorder, lineWidth: 0.8)
                }
                .shadow(
                    color: theme.activeTheme.palette.glassShadow.opacity(0.6),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
        // Avoid gestures here to ensure NavigationLink tap recognition
        .onAppear {
            updateTranscriptionState()
        }
        .onReceive(viewModel.$transcriptionStates) { _ in
            updateTranscriptionState()
        }
    }
    
    private func updateTranscriptionState() {
        transcriptionState = viewModel.getTranscriptionState(for: memo)
    }
    
}

#Preview {
    MemosView(popToRoot: nil)
}
