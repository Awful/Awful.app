import UIKit
import SwiftUI

/// Real-time performance monitoring for 120fps validation and debugging
/// Tracks frame rates, dropped frames, and animation performance
final class PerformanceMonitor: ObservableObject {
    private var displayLink: CADisplayLink?
    private var frameTimestamps: [TimeInterval] = []
    private var lastFrameTime: TimeInterval = 0
    private var frameCount = 0
    private let maxSamples = 120 // 2 seconds at 60fps
    
    @Published var currentFPS: Double = 0
    @Published var averageFPS: Double = 0
    @Published var droppedFrames: Int = 0
    @Published var isPerformingWell: Bool = true
    
    private var frameDropThreshold: TimeInterval {
        UIScreen.main.maximumFramesPerSecond > 60 ? 1.0/120.0 * 2 : 1.0/60.0 * 2
    }
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.add(to: .main, forMode: .common)
        
        lastFrameTime = CACurrentMediaTime()
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        frameTimestamps.removeAll()
        frameCount = 0
        droppedFrames = 0
    }
    
    @objc private func displayLinkFired(link: CADisplayLink) {
        let currentTime = CACurrentMediaTime()
        frameTimestamps.append(currentTime)
        frameCount += 1
        
        // Check for dropped frames
        let frameDuration = currentTime - lastFrameTime
        if frameDuration > frameDropThreshold {
            droppedFrames += 1
        }
        lastFrameTime = currentTime
        
        // Keep only recent samples
        if frameTimestamps.count > maxSamples {
            frameTimestamps.removeFirst()
        }
        
        // Calculate FPS every 30 frames to avoid excessive updates
        if frameCount % 30 == 0 {
            updateFPSMetrics()
        }
    }
    
    private func updateFPSMetrics() {
        guard frameTimestamps.count >= 2 else { return }
        
        let totalTime = frameTimestamps.last! - frameTimestamps.first!
        let framesSampled = Double(frameTimestamps.count - 1)
        
        // Calculate new values
        let newCurrentFPS = totalTime > 0 ? framesSampled / totalTime : 0
        let newAverageFPS = frameTimestamps.count == maxSamples ? framesSampled / totalTime : averageFPS
        let targetFPS = Double(UIScreen.main.maximumFramesPerSecond)
        let dropRate = Double(droppedFrames) / Double(frameCount)
        let newIsPerformingWell = newAverageFPS >= targetFPS * 0.9 && dropRate < 0.05
        
        // Update @Published properties on main thread to prevent SwiftUI warnings
        Task { @MainActor in
            self.currentFPS = newCurrentFPS
            self.averageFPS = newAverageFPS
            self.isPerformingWell = newIsPerformingWell
        }
    }
    
    /// Get performance summary for debugging
    func getPerformanceSummary() -> String {
        return """
        Current FPS: \(String(format: "%.1f", currentFPS))
        Average FPS: \(String(format: "%.1f", averageFPS))
        Target FPS: \(UIScreen.main.maximumFramesPerSecond)
        Dropped Frames: \(droppedFrames)/\(frameCount) (\(String(format: "%.1f", Double(droppedFrames) / Double(frameCount) * 100))%)
        Status: \(isPerformingWell ? "✅ Good" : "⚠️ Poor")
        """
    }
    
    /// Reset performance counters
    func reset() {
        frameTimestamps.removeAll()
        frameCount = 0
        droppedFrames = 0
        currentFPS = 0
        averageFPS = 0
        isPerformingWell = true
    }
}

/// SwiftUI overlay for real-time performance display
struct PerformanceOverlay: View {
    @StateObject private var monitor = PerformanceMonitor()
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                ZStack {
                    if isExpanded {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("FPS: \(String(format: "%.0f", monitor.currentFPS))")
                                .font(.system(.caption, design: .monospaced))
                            Text("Avg: \(String(format: "%.0f", monitor.averageFPS))")
                                .font(.system(.caption2, design: .monospaced))
                            Text("Drops: \(monitor.droppedFrames)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(monitor.droppedFrames > 0 ? .red : .green)
                        }
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                    } else {
                        Circle()
                            .fill(monitor.isPerformingWell ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .padding(8)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                    }
                }
                .frame(minWidth: 44, minHeight: 44) // Ensure minimum tap target
                .contentShape(Rectangle()) // Make entire area tappable
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 50) // Below status bar
            
            Spacer()
        }
        .allowsHitTesting(true)
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }
}

#if DEBUG
/// Debug-only performance monitoring wrapper
struct PerformanceAware<Content: View>: View {
    let content: Content
    @State private var showOverlay = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
            
            if showOverlay {
                PerformanceOverlay()
            }
        }
        .onLongPressGesture(minimumDuration: 2.0) {
            showOverlay.toggle()
        }
    }
}
#endif