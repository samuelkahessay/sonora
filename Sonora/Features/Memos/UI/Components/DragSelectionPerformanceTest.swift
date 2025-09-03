//
//  DragSelectionPerformanceTest.swift
//  Sonora
//
//  Performance testing utilities for drag-to-select implementation
//  Validates frame rates, memory usage, and edge case handling
//

#if DEBUG
import SwiftUI
import Combine

/// Performance test suite for drag-to-select functionality
/// Validates that the implementation meets our performance criteria
struct DragSelectionPerformanceTest {
    
    // MARK: - Performance Metrics
    
    struct PerformanceMetrics {
        var frameRate: Double = 0
        var memoryUsageMB: Double = 0
        var updateCount: Int = 0
        var droppedFrames: Int = 0
        var averageUpdateTime: TimeInterval = 0
        var maxUpdateTime: TimeInterval = 0
        
        var isPerformanceAcceptable: Bool {
            frameRate >= 55 && // Allow for small drops from 60fps
            averageUpdateTime <= 0.016 && // 16ms for 60fps
            droppedFrames <= updateCount / 10 // Max 10% dropped frames
        }
    }
    
    // MARK: - Edge Case Test Scenarios
    
    enum TestScenario: CaseIterable {
        case smallList // 5 items
        case mediumList // 50 items
        case largeList // 500 items
        case veryLargeList // 1000 items
        case fastDrag // High velocity drag
        case slowDrag // Low velocity drag
        case rapidDirectionChanges // Quick back and forth
        case edgeScrolling // Near list boundaries
        case memoryPressure // Low memory conditions
        
        var description: String {
            switch self {
            case .smallList: return "Small list (5 items)"
            case .mediumList: return "Medium list (50 items)"
            case .largeList: return "Large list (500 items)"
            case .veryLargeList: return "Very large list (1000+ items)"
            case .fastDrag: return "Fast drag (high velocity)"
            case .slowDrag: return "Slow drag (low velocity)"
            case .rapidDirectionChanges: return "Rapid direction changes"
            case .edgeScrolling: return "Edge scrolling behavior"
            case .memoryPressure: return "Memory pressure handling"
            }
        }
        
        var expectedItemCount: Int {
            switch self {
            case .smallList: return 5
            case .mediumList: return 50
            case .largeList: return 500
            case .veryLargeList: return 1000
            default: return 50
            }
        }
    }
    
    // MARK: - Test Results
    
    struct TestResult {
        let scenario: TestScenario
        let metrics: PerformanceMetrics
        let passed: Bool
        let details: String
        
        var summary: String {
            let status = passed ? "✅ PASS" : "❌ FAIL"
            return "\(status): \(scenario.description) - \(String(format: "%.1f", metrics.frameRate))fps, \(String(format: "%.1f", metrics.averageUpdateTime * 1000))ms avg"
        }
    }
    
    // MARK: - Performance Monitor
    
    class PerformanceMonitor: ObservableObject {
        @Published var currentMetrics = PerformanceMetrics()
        @Published var isMonitoring = false
        
        private var frameTimestamps: [Date] = []
        private var updateTimes: [TimeInterval] = []
        private var cancellables = Set<AnyCancellable>()
        
        func startMonitoring() {
            isMonitoring = true
            frameTimestamps.removeAll()
            updateTimes.removeAll()
            
            // Monitor updates every frame
            Timer.publish(every: 1.0/60.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] timestamp in
                    self?.recordFrame(at: timestamp)
                }
                .store(in: &cancellables)
            
            // Calculate metrics every second
            Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.updateMetrics()
                }
                .store(in: &cancellables)
        }
        
        func stopMonitoring() {
            isMonitoring = false
            cancellables.removeAll()
        }
        
        func recordUpdateTime(_ time: TimeInterval) {
            updateTimes.append(time)
            
            // Keep history manageable
            if updateTimes.count > 100 {
                updateTimes.removeFirst()
            }
        }
        
        private func recordFrame(at timestamp: Date) {
            frameTimestamps.append(timestamp)
            
            // Keep only last second of frames
            let cutoff = timestamp.addingTimeInterval(-1.0)
            frameTimestamps.removeAll { $0 < cutoff }
        }
        
        private func updateMetrics() {
            currentMetrics.frameRate = Double(frameTimestamps.count)
            currentMetrics.updateCount = updateTimes.count
            currentMetrics.memoryUsageMB = getMemoryUsage()
            
            if !updateTimes.isEmpty {
                currentMetrics.averageUpdateTime = updateTimes.reduce(0, +) / Double(updateTimes.count)
                currentMetrics.maxUpdateTime = updateTimes.max() ?? 0
                
                // Count dropped frames (updates taking longer than 16ms)
                currentMetrics.droppedFrames = updateTimes.filter { $0 > 0.016 }.count
            }
        }
        
        private func getMemoryUsage() -> Double {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            
            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                             task_flavor_t(MACH_TASK_BASIC_INFO),
                             $0,
                             &count)
                }
            }
            
            if kerr == KERN_SUCCESS {
                return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
            }
            return 0
        }
    }
    
    // MARK: - Test Suite
    
    /// Run comprehensive performance tests
    static func runTests() async -> [TestResult] {
        var results: [TestResult] = []
        
        for scenario in TestScenario.allCases {
            let result = await runTest(for: scenario)
            results.append(result)
        }
        
        return results
    }
    
    /// Run a specific test scenario
    static func runTest(for scenario: TestScenario) async -> TestResult {
        let monitor = PerformanceMonitor()
        monitor.startMonitoring()
        
        // Simulate the scenario
        await simulateScenario(scenario, monitor: monitor)
        
        // Wait for metrics to stabilize
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let metrics = monitor.currentMetrics
        monitor.stopMonitoring()
        
        let passed = validateScenario(scenario, metrics: metrics)
        let details = generateTestDetails(scenario: scenario, metrics: metrics)
        
        return TestResult(
            scenario: scenario,
            metrics: metrics,
            passed: passed,
            details: details
        )
    }
    
    // MARK: - Scenario Simulation
    
    private static func simulateScenario(_ scenario: TestScenario, monitor: PerformanceMonitor) async {
        switch scenario {
        case .fastDrag:
            await simulateFastDrag(monitor: monitor)
        case .slowDrag:
            await simulateSlowDrag(monitor: monitor)
        case .rapidDirectionChanges:
            await simulateRapidDirectionChanges(monitor: monitor)
        case .edgeScrolling:
            await simulateEdgeScrolling(monitor: monitor)
        case .memoryPressure:
            await simulateMemoryPressure(monitor: monitor)
        default:
            await simulateStandardDrag(itemCount: scenario.expectedItemCount, monitor: monitor)
        }
    }
    
    private static func simulateFastDrag(monitor: PerformanceMonitor) async {
        // Simulate 50 rapid updates (fast drag)
        let startTime = Date()
        
        for i in 0..<50 {
            let updateStart = Date()
            
            // Simulate drag update processing
            let _ = SelectionInterpolator.interpolateSelection(
                from: 0,
                to: i,
                velocity: 800, // High velocity
                rowHeight: 80,
                maxItems: 100
            )
            
            let updateTime = Date().timeIntervalSince(updateStart)
            monitor.recordUpdateTime(updateTime)
            
            // Wait 16ms for next frame
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
    
    private static func simulateSlowDrag(monitor: PerformanceMonitor) async {
        // Simulate 30 slow updates
        for i in 0..<30 {
            let updateStart = Date()
            
            let _ = SelectionInterpolator.interpolateSelection(
                from: 0,
                to: i,
                velocity: 100, // Low velocity
                rowHeight: 80,
                maxItems: 100
            )
            
            let updateTime = Date().timeIntervalSince(updateStart)
            monitor.recordUpdateTime(updateTime)
            
            // Wait 33ms for slower updates
            try? await Task.sleep(nanoseconds: 33_000_000)
        }
    }
    
    private static func simulateRapidDirectionChanges(monitor: PerformanceMonitor) async {
        // Simulate back and forth dragging
        var direction = 1
        var currentIndex = 25
        
        for i in 0..<40 {
            let updateStart = Date()
            
            currentIndex += direction * 3
            if currentIndex <= 0 || currentIndex >= 50 {
                direction *= -1
            }
            
            let _ = SelectionInterpolator.interpolateSelection(
                from: 25,
                to: currentIndex,
                velocity: 400,
                rowHeight: 80,
                maxItems: 50
            )
            
            let updateTime = Date().timeIntervalSince(updateStart)
            monitor.recordUpdateTime(updateTime)
            
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
    
    private static func simulateEdgeScrolling(monitor: PerformanceMonitor) async {
        // Test selection at list boundaries
        let scenarios = [(0, 5), (95, 100), (0, 100)] // start, end pairs
        
        for (start, end) in scenarios {
            for i in stride(from: start, through: end, by: 1) {
                let updateStart = Date()
                
                let _ = SelectionInterpolator.interpolateSelection(
                    from: start,
                    to: i,
                    velocity: 300,
                    rowHeight: 80,
                    maxItems: 100
                )
                
                let updateTime = Date().timeIntervalSince(updateStart)
                monitor.recordUpdateTime(updateTime)
                
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
    
    private static func simulateMemoryPressure(monitor: PerformanceMonitor) async {
        // Create memory pressure by generating large temporary objects
        var tempObjects: [[Int]] = []
        
        for i in 0..<20 {
            let updateStart = Date()
            
            // Create temporary memory pressure
            tempObjects.append(Array(0..<10000))
            
            let _ = SelectionInterpolator.interpolateSelection(
                from: 0,
                to: i,
                velocity: 300,
                rowHeight: 80,
                maxItems: 50
            )
            
            // Clean up every few iterations
            if tempObjects.count > 5 {
                tempObjects.removeFirst()
            }
            
            let updateTime = Date().timeIntervalSince(updateStart)
            monitor.recordUpdateTime(updateTime)
            
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
        
        tempObjects.removeAll() // Clean up
    }
    
    private static func simulateStandardDrag(itemCount: Int, monitor: PerformanceMonitor) async {
        let steps = min(itemCount / 2, 50) // Don't test more than 50 steps
        
        for i in 0..<steps {
            let updateStart = Date()
            
            let _ = SelectionInterpolator.interpolateSelection(
                from: 0,
                to: i,
                velocity: 300,
                rowHeight: 80,
                maxItems: itemCount
            )
            
            let updateTime = Date().timeIntervalSince(updateStart)
            monitor.recordUpdateTime(updateTime)
            
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
    
    // MARK: - Validation
    
    private static func validateScenario(_ scenario: TestScenario, metrics: PerformanceMetrics) -> Bool {
        // Base performance requirements
        let baseRequirements = metrics.isPerformanceAcceptable
        
        // Scenario-specific requirements
        switch scenario {
        case .veryLargeList:
            // Allow slightly lower performance for very large lists
            return metrics.frameRate >= 50 && metrics.averageUpdateTime <= 0.020
        case .memoryPressure:
            // Check memory didn't increase excessively
            return baseRequirements && metrics.memoryUsageMB < 200 // Reasonable limit
        case .fastDrag:
            // Should handle fast drags without significant drops
            return metrics.frameRate >= 58 && metrics.droppedFrames <= metrics.updateCount / 20
        default:
            return baseRequirements
        }
    }
    
    private static func generateTestDetails(scenario: TestScenario, metrics: PerformanceMetrics) -> String {
        return """
        Frame Rate: \(String(format: "%.1f", metrics.frameRate))fps
        Average Update Time: \(String(format: "%.2f", metrics.averageUpdateTime * 1000))ms
        Max Update Time: \(String(format: "%.2f", metrics.maxUpdateTime * 1000))ms
        Dropped Frames: \(metrics.droppedFrames)/\(metrics.updateCount)
        Memory Usage: \(String(format: "%.1f", metrics.memoryUsageMB))MB
        """
    }
}

// MARK: - Test UI (Debug)

struct PerformanceTestView: View {
    @State private var testResults: [DragSelectionPerformanceTest.TestResult] = []
    @State private var isRunning = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isRunning {
                    ProgressView("Running performance tests...")
                        .padding()
                } else {
                    Button("Run Performance Tests") {
                        runTests()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                }
                
                List(testResults, id: \.scenario) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.summary)
                            .font(.headline)
                            .foregroundColor(result.passed ? .green : .red)
                        
                        Text(result.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Drag Selection Performance")
        }
    }
    
    private func runTests() {
        isRunning = true
        Task {
            let results = await DragSelectionPerformanceTest.runTests()
            await MainActor.run {
                self.testResults = results
                self.isRunning = false
            }
        }
    }
}

#Preview {
    PerformanceTestView()
}

#endif