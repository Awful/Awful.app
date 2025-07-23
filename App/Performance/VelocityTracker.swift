import UIKit

/// High-performance velocity tracker using CADisplayLink for 120fps animation support
/// Optimized for ProMotion displays with minimal memory allocation
final class VelocityTracker {
    private struct Sample {
        let time: TimeInterval
        let offset: CGFloat
    }
    
    private var samples: [Sample] = []
    private let maxSamples = 3
    private let minSamplesForVelocity = 2
    
    /// Current velocity in points per second
    var velocity: CGFloat {
        guard samples.count >= minSamplesForVelocity else { return 0 }
        
        let firstSample = samples.first!
        let lastSample = samples.last!
        
        let deltaTime = lastSample.time - firstSample.time
        let deltaOffset = lastSample.offset - firstSample.offset
        
        return deltaTime > 0 ? deltaOffset / deltaTime : 0
    }
    
    /// Smoothed velocity using weighted average of recent samples
    var smoothedVelocity: CGFloat {
        guard samples.count >= minSamplesForVelocity else { return 0 }
        
        var totalWeight: CGFloat = 0
        var weightedVelocity: CGFloat = 0
        
        for i in 1..<samples.count {
            let prevSample = samples[i-1]
            let currSample = samples[i]
            
            let deltaTime = currSample.time - prevSample.time
            let deltaOffset = currSample.offset - prevSample.offset
            
            if deltaTime > 0 {
                let weight = CGFloat(i) // Recent samples get more weight
                let velocity = deltaOffset / deltaTime
                
                weightedVelocity += velocity * weight
                totalWeight += weight
            }
        }
        
        return totalWeight > 0 ? weightedVelocity / totalWeight : 0
    }
    
    /// True if scrolling is actively happening (velocity above threshold)
    var isActivelyScrolling: Bool {
        abs(velocity) > 50 // Balanced threshold with momentum-based DisplayLink management
    }
    
    /// Add a new scroll position sample with current timestamp
    /// - Parameter offset: Current scroll offset (y position)
    func addSample(_ offset: CGFloat) {
        let now = CACurrentMediaTime()
        samples.append(Sample(time: now, offset: offset))
        
        // Keep only the most recent samples for performance
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }
    
    /// Reset all samples (call when scrolling stops or view disappears)
    func reset() {
        samples.removeAll(keepingCapacity: true)
    }
    
    /// Get velocity direction for UI animations
    var scrollDirection: ScrollDirection {
        let vel = velocity
        if abs(vel) < 50 { return .none }
        return vel > 0 ? .down : .up
    }
}

enum ScrollDirection {
    case up, down, none
}