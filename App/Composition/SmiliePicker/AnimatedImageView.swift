//  AnimatedImageView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import FLAnimatedImage

// Helper class to store weak references
private class Weak<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

// Simple LRU cache for animated images
private class AnimatedImageCache {
    static let shared = AnimatedImageCache()
    
    private var cache = NSCache<NSString, FLAnimatedImage>()
    
    init() {
        cache.countLimit = 50 // Cache up to 50 images
        cache.totalCostLimit = 50 * 1024 * 1024 // ~50MB
    }
    
    func image(for key: String) -> FLAnimatedImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: FLAnimatedImage, for key: String) {
        let cost = image.data?.count ?? 0
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

/// SwiftUI wrapper for FLAnimatedImageView to display animated GIFs
struct AnimatedImageView: UIViewRepresentable {
    let data: Data
    let imageID: String // Unique identifier for this image
    
    class Coordinator {
        var currentTask: Task<Void, Never>?
        var currentImageID: String?
        
        func cancelCurrentTask() {
            currentTask?.cancel()
            currentTask = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> FLAnimatedImageView {
        let imageView = FLAnimatedImageView()
        imageView.contentMode = .scaleAspectFit
        // Use nearest neighbor scaling to preserve pixelated aesthetic
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        return imageView
    }
    
    func updateUIView(_ uiView: FLAnimatedImageView, context: Context) {
        // Check if we need to load this image (either first time or different image)
        let needsLoad = context.coordinator.currentImageID != imageID || 
                       (uiView.animatedImage == nil && uiView.image == nil && context.coordinator.currentTask == nil)
        
        if needsLoad {
            // Cancel any existing task if loading a different image
            if context.coordinator.currentImageID != imageID {
                context.coordinator.cancelCurrentTask()
            }
            context.coordinator.currentImageID = imageID
            
            // Clear the current images immediately
            uiView.animatedImage = nil
            uiView.image = nil
            
            // Store weak reference to avoid retain cycles
            let weakView = Weak(uiView)
            
            // Load the new animated image asynchronously
            let task = Task {
                // Check cache first
                var animatedImage = AnimatedImageCache.shared.image(for: imageID)
                
                // If not in cache, load it
                if animatedImage == nil {
                    animatedImage = await Task.detached(priority: .userInitiated) {
                        if let image = FLAnimatedImage(animatedGIFData: data) {
                            AnimatedImageCache.shared.setImage(image, for: imageID)
                            return image
                        }
                        return nil
                    }.value
                }
                
                // Only update if this task hasn't been cancelled and we're still showing the same image
                if !Task.isCancelled && context.coordinator.currentImageID == imageID {
                    await MainActor.run {
                        // Double-check we're still showing the same image after switching to main actor
                        guard context.coordinator.currentImageID == imageID else {
                            return
                        }
                        
                        // Ensure the view is still valid
                        guard let strongView = weakView.value else {
                            return
                        }
                        
                        if let animatedImage = animatedImage {
                            let frameCount = animatedImage.frameCount
                            strongView.animatedImage = animatedImage
                            
                            // For single-frame GIFs, FLAnimatedImageView might not display properly
                            // So we also set the static image
                            if frameCount == 1, let staticImage = UIImage(data: data) {
                                strongView.image = staticImage
                            } else {
                                strongView.image = nil
                                // Start animating if needed
                                if !strongView.isAnimating && frameCount > 1 {
                                    strongView.startAnimating()
                                }
                            }
                            
                            // Force layout update
                            strongView.setNeedsLayout()
                            strongView.setNeedsDisplay()
                        } else {
                            // Log failure but keep the view empty rather than showing an error
                            print("AnimatedImageView: Failed to create FLAnimatedImage for \(imageID)")
                        }
                    }
                }
            }
            context.coordinator.currentTask = task
        }
    }
    
    static func dismantleUIView(_ uiView: FLAnimatedImageView, coordinator: Coordinator) {
        coordinator.cancelCurrentTask()
        uiView.stopAnimating()
        uiView.animatedImage = nil
        uiView.image = nil
    }
}
