# Project Overview

**Sonora** is a modern iOS voice memo application with AI-powered analysis. It is designed for high reliability, testability, and maintainability, built upon Clean Architecture principles.

*   **Purpose:** To provide a sophisticated voice memo experience on iOS with integrated AI analysis capabilities.
*   **Main Technologies:**
    *   **Frontend (iOS App):** Swift, SwiftUI, SwiftData (for local persistence), WhisperKit (for on-device transcription), LLM.swift, swift-transformers, ZIPFoundation.
    *   **Backend (API Server):** Node.js, Express, TypeScript, Zod (for schema validation), Multer (for file uploads), OpenAI API (for transcription and AI analysis).
    *   **Deployment:** The backend server is deployed using Fly.io.
*   **Architecture:** Adheres to Clean Architecture principles with MVVM (Model-View-ViewModel) at the Presentation layer. It features clearly defined layers: Presentation, Domain, Data, and Core. The application leverages an Event-Driven Architecture for decoupled communication between components and an Operation Coordination System for managing long-running, concurrent tasks.

# Building and Running

## iOS App

*   **Dependencies:** Swift Package Manager (SPM) is used for managing all Swift-based dependencies (e.g., WhisperKit, LLM.swift, swift-transformers, ZIPFoundation). Xcode automatically handles the resolution and integration of these packages.
*   **Build:** Open the `Sonora.xcodeproj` file in Xcode. Select the `Sonora` target and build the project.
*   **Run:** After a successful build, run the `Sonora` target on an iOS Simulator or a connected physical iOS device directly from Xcode.
*   **Testing:**
    *   Unit tests are located in the `SonoraTests/` directory.
    *   UI tests are located in the `SonoraUITests/` directory.
    *   Tests can be executed directly from Xcode.
*   **Environment Variables (for iOS App):**
    *   `SONORA_MAX_RECORDING_DURATION`: Overrides the default 60-second recording limit (e.g., `SONORA_MAX_RECORDING_DURATION=120` for 2 minutes).
    *   `HF_HUB_DISABLE_TELEMETRY`, `HUGGINGFACE_HUB_DISABLE_TELEMETRY`: Set to `"1"` to disable telemetry collection by Hugging Face libraries.
    *   `HF_HOME`, `TRANSFORMERS_CACHE`: These are set internally by the app to point to specific subdirectories within the app's Documents directory for storing Hugging Face/WhisperKit models and caches.

## Backend (API Server)

*   **Dependencies:** Requires Node.js and either npm or yarn.
    *   Navigate to the `server/` directory in your terminal.
    *   Install required Node.js packages by running: `npm install` (or `yarn install`).
*   **Build:**
    *   To compile the TypeScript source code into JavaScript, run: `npm run build`.
    *   The compiled JavaScript files will be output to the `dist/` directory.
*   **Run (Development Mode):**
    *   To run the server in development mode with live reloading (using `tsx`): `npm run dev`.
*   **Run (Production Mode):**
    *   To run the compiled server in production mode: `npm start`.
*   **Configuration (Environment Variables for Backend):**
    *   `PORT`: Specifies the port the server listens on (defaults to `8080`).
    *   `CORS_ORIGIN`: Sets the allowed origin for Cross-Origin Resource Sharing (CORS) requests (defaults to `https://sonora.app`).
    *   `OPENAI_API_KEY`: **Critical** - Your OpenAI API key, required for all transcription and AI analysis functionalities.
    *   `SONORA_MODEL`: (Optional) Overrides the default GPT-5-nano model used for AI analysis.
*   **Deployment:**
    *   The backend server is configured for deployment to Fly.io using the `fly.toml` configuration file located in the `server/` directory.
    *   Health checks are configured on the `/` path, aligning with the server's health check endpoint.

# Development Conventions

*   **Architecture:** The project strictly adheres to Clean Architecture principles, with a clear separation of concerns across Presentation, Domain, Data, and Core layers. MVVM is used within the Presentation layer.
*   **Layer Boundaries:** Strict rules govern dependencies between layers. Direct imports between different feature modules are avoided; communication is facilitated through the `EventBus` and shared repository state.
*   **Dependency Injection:** A "protocol-first" approach is used for dependency injection. Dependencies are injected via constructors, and the `DIContainer` serves as the central composition root for resolving concrete implementations.
*   **Concurrency:** The project extensively utilizes Swift's modern concurrency features (`async/await`) and the `OperationCoordinator` for managing long-running, thread-safe operations and handling conflicts.
*   **Event System:** An `EventBus` and `AppEvent` system are in place to enable decoupled, reactive communication between various components of the application.
*   **Error Handling:** Custom error types are defined, and errors are mapped to domain-specific `SonoraError` instances via an `ErrorMapping` utility.
*   **Logging:** Structured logging is implemented using a `Logger` class, allowing for contextual logging with `LogContext`.
*   **UI Implementation:** The user interface is built using native SwiftUI components, leveraging system theming for automatic light/dark mode adaptation and a semantic color system for consistent visual styling.
*   **Testing:** There is a strong emphasis on testing, particularly for Use Cases (business logic) and ViewModels (presentation logic), using protocol-backed fakes for isolation. Detailed testing guides and procedures are available in the `docs/testing/` directory.
*   **Code Style:** The codebase implicitly follows standard Swift/SwiftUI coding conventions. Specific guidelines, such as the mandatory use of semantic colors, are enforced.
