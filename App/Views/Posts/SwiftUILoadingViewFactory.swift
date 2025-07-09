//  SwiftUILoadingViewFactory.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import AwfulTheming
import AwfulModelTypes
import Lottie
import FLAnimatedImage

struct SwiftUILoadingViewFactory {
    static func loadingView(for theme: Theme) -> some View {
        Group {
            switch theme[string: "postsLoadingViewType"] {
            case "Macinyos":
                SwiftUIMacinyosLoadingView(theme: theme)
            case "Winpos95":
                SwiftUIWinpos95LoadingView(theme: theme)
            case "YOSPOS":
                SwiftUIYOSPOSLoadingView(theme: theme)
            default:
                SwiftUIDefaultLoadingView(theme: theme)
            }
        }
    }
}

// MARK: - Default Loading View (Lottie mainthrobber)
struct SwiftUIDefaultLoadingView: View {
    let theme: Theme
    
    var body: some View {
        DefaultLottieLoadingView(theme: theme)
            .frame(width: 90, height: 90)
            .background(Color(theme[uicolor: "postsLoadingViewTintColor"] ?? .systemBackground))
    }
}

private struct DefaultLottieLoadingView: UIViewRepresentable {
    let theme: Theme
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(
            animation: LottieAnimation.named("mainthrobber60"),
            configuration: LottieConfiguration(renderingEngine: .mainThread)
        )
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.animationSpeed = 1
        animationView.backgroundBehavior = .pauseAndRestore
        
        // Apply theme colors
        let color = ColorValueProvider(theme["activityIndicatorColor"]?.lottieColorValue ?? UIColor.systemBlue.lottieColorValue)
        let keypath = AnimationKeypath(keys: ["**", "**", "**", "Color"])
        animationView.setValueProvider(color, keypath: keypath)
        
        // Two-phase animation: play frames 0-25 once, then loop 25-infinity
        animationView.play(fromFrame: 0, toFrame: 25, loopMode: .playOnce) { completed in
            if completed {
                animationView.loopMode = .loop
                animationView.play()
            }
        }
        
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // Update theme colors if needed
        let color = ColorValueProvider(theme["activityIndicatorColor"]?.lottieColorValue ?? UIColor.systemBlue.lottieColorValue)
        let keypath = AnimationKeypath(keys: ["**", "**", "**", "Color"])
        uiView.setValueProvider(color, keypath: keypath)
    }
}

// MARK: - YOSPOS Loading View (ASCII Terminal Spinner)
struct SwiftUIYOSPOSLoadingView: View {
    let theme: Theme
    
    @State private var currentSpinnerIndex = 0
    
    private let spinnerChars = ["|", "/", "-", "\\"]
    
    var body: some View {
        Text(spinnerChars[currentSpinnerIndex])
            .font(.custom("Menlo", size: 15))
            .foregroundColor(Color(theme[uicolor: "postsLoadingViewTintColor"] ?? .label))
            .frame(width: 90, height: 90)
            .background(Color.black) // YOSPOS uses black background like UIKit version
            .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in
                currentSpinnerIndex = (currentSpinnerIndex + 1) % spinnerChars.count
            }
    }
}

// MARK: - Macinyos Loading View (Static Mac Image)
struct SwiftUIMacinyosLoadingView: View {
    let theme: Theme
    
    var body: some View {
        ZStack {
            // Tiled wallpaper background
            if let wallpaperImage = UIImage(named: "macinyos-wallpaper") {
                Image(uiImage: wallpaperImage)
                    .resizable(resizingMode: .tile)
                    .frame(width: 90, height: 90)
                    .clipped()
            }
            
            // Loading image with border
            if let loadingImage = UIImage(named: "macinyos-loading") {
                Image(uiImage: loadingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .border(Color.black, width: 1)
            }
        }
        .frame(width: 90, height: 90)
    }
}

// MARK: - Winpos95 Loading View (Draggable Animated GIF)
struct SwiftUIWinpos95LoadingView: View {
    let theme: Theme
    
    @State private var hourglassPosition = CGPoint(x: 45, y: 45) // Center of 90x90 frame
    
    var body: some View {
        ZStack {
            // Teal background
            Color(red: 0, green: 0.5, blue: 0.5) // #008080
                .frame(width: 90, height: 90)
            
            // Animated hourglass GIF
            if let hourglassPath = Bundle.main.path(forResource: "hourglass", ofType: "gif"),
               let hourglassData = NSData(contentsOfFile: hourglassPath) {
                AnimatedGIFView(data: hourglassData)
                    .frame(width: 32, height: 32)
                    .position(hourglassPosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Constrain to 90x90 frame
                                let newX = max(16, min(74, value.location.x))
                                let newY = max(16, min(74, value.location.y))
                                hourglassPosition = CGPoint(x: newX, y: newY)
                            }
                    )
            }
        }
        .frame(width: 90, height: 90)
    }
}

// Helper for animated GIF display
private struct AnimatedGIFView: UIViewRepresentable {
    let data: NSData
    
    func makeUIView(context: Context) -> FLAnimatedImageView {
        let imageView = FLAnimatedImageView()
        imageView.animatedImage = FLAnimatedImage(animatedGIFData: data as Data)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    func updateUIView(_ uiView: FLAnimatedImageView, context: Context) {
        // No updates needed
    }
}