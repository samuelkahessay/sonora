# Sonora Project Overview

## Project Purpose
Sonora is a sophisticated Swift iOS voice memo app with AI analysis, showcasing exemplary Clean Architecture (95% compliance) and native SwiftUI implementation. It's a production-ready voice recording app with transcription, AI-powered analysis, and EventKit integration.

## Tech Stack
- **Language**: Swift 6 with strict concurrency
- **UI Framework**: Native SwiftUI with standard Apple components
- **Architecture**: Clean Architecture (MVVM + Use Cases + Repositories)
- **Concurrency**: @MainActor isolation with async/await patterns
- **Dependency Injection**: Protocol-based DI via DIContainer
- **Audio**: AVFoundation with background recording support
- **AI Services**: Transcription (local WhisperKit + cloud) + Analysis services
- **Data**: SwiftData for persistence with intelligent caching
- **Frameworks**: EventKit for calendar/reminders, Live Activities for recording status

## Architecture Layers
1. **Presentation**: SwiftUI Views + @MainActor ViewModels with @Published state
2. **Domain**: Use Cases (29 total) + Domain Models + Protocol contracts
3. **Data**: Repository implementations + Services for external APIs

## Code Style & Conventions
- **Naming**: Swift standard (camelCase for properties/methods, PascalCase for types)
- **Concurrency**: All UI components @MainActor, Use Cases actor-agnostic, Repositories @MainActor for framework integration
- **Protocols**: `any Protocol` syntax required for Swift 6
- **Dependencies**: Constructor injection with protocol abstractions
- **Logging**: Structured logging with LogContext and correlation IDs

## Architecture Excellence Metrics
- **Domain Layer**: 97% compliance with perfect layer separation
- **Clean Architecture**: 95% overall compliance
- **Protocol-Based Dependencies**: 95% (up from 30%)
- **Legacy Code Eliminated**: 570+ lines removed during modernization