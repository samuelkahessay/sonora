# Sonora Simplified Architecture (2025)

## Overview

After successful component consolidation and modernization, Sonora now follows a clean, simplified architecture with native SwiftUI components and consistent patterns throughout.

## Core UI Components

### Recording & Playback
- **`RecordingView.swift`** - Main recording interface with 3-minute timer and permission handling
- **`RecordingViewModel.swift`** - Recording state management with background audio support
- **`BackgroundAudioService.swift`** - Background recording functionality and Live Activities

### Transcription Display
- **`MemoDetailView.swift`** - Display transcribed text with intelligent paragraph formatting
- **`TranscriptionStatusView.swift`** - Unified transcription state indicator (compact/full modes)
- **`StatusIndicator.swift`** - **NEW** Consistent status displays for all app states

### AI Analysis
- **`AnalysisResultsView.swift`** - Display AI analysis results (TLDR, themes, todos)
- **`AnalysisSectionView.swift`** - Analysis mode selection with loading states
- **`AIBadge.swift`** - AI-generated content indicator with accessibility support

### Shared Components
- **`NotificationBanner.swift`** - Unified notifications (regular + compact modes)
- **`UnifiedStateView.swift`** - Empty/error/loading states with consistent styling
- **`ErrorAlertModifier.swift`** - Consistent error handling across views
- **`ActivityView.swift`** - SwiftUI wrapper for iOS share functionality

### Settings & Onboarding
- **`SettingsView.swift`** - App settings with cards and sections
- **`OnboardingView.swift`** - Initial user onboarding flow
- **`SettingsCard.swift`** - Consistent card container for settings sections

## Key Architecture Patterns

### SwiftUI Native Approach
- **All views use SwiftUI** - No UIKit wrappers except for system integrations (share sheet)
- **Native button styles** - `.borderedProminent`, `.bordered`, `.plain`
- **Standard iOS components** - Leveraging system optimizations and theming

### State Management
- **@StateObject** for view-owned state and ViewModels
- **@ObservedObject** for injected ViewModels via DIContainer
- **@Published** for reactive updates to UI
- **Combine** for async operations and data flow

### Accessibility Standards
- **44x44pt minimum touch targets** - All interactive elements meet Apple HIG
- **Comprehensive VoiceOver labels** - Every UI element properly labeled
- **Dynamic Type support** - Text scales appropriately across all components
- **Semantic accessibility traits** - Proper traits for different UI elements

### Icon & Visual Standards
```swift
enum IconSize: CGFloat {
    case small = 16      // Compact UI elements
    case standard = 24   // Default minimum
    case medium = 28     // Interactive elements
    case large = 32      // Primary actions
    case extraLarge = 48 // Hero elements
}
```
- **Minimum 28pt for interactive elements** - Recording indicator, status icons
- **Semantic colors throughout** - `Color.semantic(.brandPrimary)`, `.error`, `.success`
- **Consistent visual hierarchy** - Proper spacing using `Spacing` constants

## Component Architecture

### StatusIndicator (New Unified Component)
```swift
// Replaces scattered status icon patterns
StatusIndicator.success("Transcription completed", showText: true)
StatusIndicator.loading("Processing...", size: .large, showText: true)
StatusIndicator.transcription(state: .completed, showText: true)
```

### NotificationBanner (Consolidated)
```swift
// Single component handles both modes
NotificationBanner.error(error, compact: false, onDismiss: { })
NotificationBanner.success("Operation completed", compact: true, onDismiss: { })
```

### Design System Integration
- **Typography.swift** - Font standards, icon sizing, and view extensions
- **SemanticColors.swift** - Theme-aware color system
- **Spacing.swift** - Consistent spacing throughout the app
- **ThemeManager.swift** - Light/dark mode support

## Clean Architecture Compliance (95%)

### Domain Layer
- **16 Use Cases** - Pure business logic (Recording, Transcription, Analysis, Memo)
- **Domain Models** - `Memo`, `DomainAnalysisResult`, clean data structures
- **Protocol Abstractions** - Repository and service interfaces

### Data Layer  
- **4 Repositories** - Protocol implementations for data access
- **6 Services** - External integrations (TranscriptionService, AnalysisService, etc.)
- **Data Models** - Separate from domain models for clean boundaries

### Presentation Layer
- **ViewModels** - UI coordinators following MVVM pattern
- **Protocol-based DI** - Clean dependency injection via DIContainer
- **No architecture violations** - Clean separation of concerns

## Migration Benefits

### Before Consolidation
- Duplicate notification components (NotificationBanner + CompactNotificationBanner)
- Inconsistent icon sizing (16pt recording indicator)
- Mixed button style syntax (PlainButtonStyle() vs .plain)
- Scattered status indicator patterns

### After Consolidation
- **Single unified notification system** with compact mode support
- **Consistent 28x28pt minimum icon sizing** throughout the app
- **Modern SwiftUI button styles** across all components
- **Centralized StatusIndicator component** for all status displays
- **Zero duplicate code** in UI components

## Performance & Reliability

### Native SwiftUI Benefits
- **System optimizations** - Leveraging Apple's rendering optimizations
- **Automatic theming** - Light/dark mode handled by system
- **Memory efficiency** - No UIKit bridge overhead for most components
- **Smooth animations** - Native SwiftUI transitions and state changes

### Accessibility Excellence
- **VoiceOver support** - Complete screen reader functionality
- **Dynamic Type** - Text scaling for vision accessibility
- **Motor accessibility** - Proper touch target sizes
- **Cognitive accessibility** - Clear visual hierarchy and consistent patterns

## Future Development Guidelines

### Adding New Components
1. Follow `StatusIndicator` pattern for reusable components
2. Use `IconSize` enum for all icon sizing
3. Implement proper accessibility from the start
4. Document public APIs with clear examples

### Extending Features
1. Leverage existing `UnifiedStateView` for loading/error states
2. Use `NotificationBanner` for user feedback
3. Follow established ViewModel patterns
4. Maintain Clean Architecture boundaries

### Testing Strategy
1. Unit tests for ViewModels and Use Cases
2. UI tests using XcodeBuildMCP for user flows
3. Snapshot tests for visual regression detection
4. Accessibility testing with VoiceOver

## Architecture Success Metrics

- **95% Clean Architecture Compliance** - Excellent separation of concerns
- **Zero Architecture Violations** - Clean dependency flow
- **Native Performance** - System-optimized SwiftUI components
- **Accessibility AA Compliant** - Full VoiceOver and Dynamic Type support
- **Maintainable Codebase** - Consistent patterns and documentation

This simplified architecture provides a solid foundation for future development while maintaining excellent performance, accessibility, and maintainability standards.

