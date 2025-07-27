//  SmilieGridItem.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI
import Smilies
import UniformTypeIdentifiers
import AwfulTheming

struct SmilieGridItem: View {
    @ObservedObject var smilie: Smilie
    let onTap: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme: Theme
    @State private var uiImage: UIImage?
    @State private var imageLoadAttempted = false
    @State private var retryCount = 0
    
    private let itemSize: CGFloat = 90
    private let maxRetries = 2
    
    private var shouldUseAnimatedView: Bool {
        guard let imageUTI = smilie.imageUTI else { 
            return false 
        }
        // Use AnimatedImageView for all GIFs
        return imageUTI == "com.compuserve.gif" || UTType(imageUTI)?.conforms(to: .gif) ?? false
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    // Always show background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColorForIcon)
                        .frame(width: itemSize, height: itemSize)
                    
                    Group {
                        if let imageData = smilie.imageData {
                            if shouldUseAnimatedView {
                                // For all GIFs (animated or single-frame), use AnimatedImageView
                                AnimatedImageView(data: imageData, imageID: smilie.text)
                                    .frame(maxWidth: itemSize - 16, maxHeight: itemSize - 16)
                                    .aspectRatio(contentMode: .fit)
                                    .clipped()
                            } else if let uiImage = uiImage {
                                // For non-GIF images
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: itemSize - 16, maxHeight: itemSize - 16)
                                    .clipped()
                            } else if imageLoadAttempted {
                                // Invalid image data
                                placeholderView
                            } else {
                                // Show loading state while image loads
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: itemSize - 16, height: itemSize - 16)
                            }
                        } else {
                            // No image data
                            placeholderView
                        }
                    }
                }
                .frame(width: itemSize, height: itemSize)
                
                Text(smilie.text)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .foregroundColor(theme[color: "sheetTextColor"]!)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: itemSize, height: 24)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SmilieButtonStyle())
        .accessibilityLabel(smilie.summary ?? smilie.text)
        .onAppear {
            // Only load if it's not a GIF (GIFs are handled by AnimatedImageView)
            if !shouldUseAnimatedView {
                loadImageIfNeeded()
                
                // Retry if image hasn't loaded after a short delay
                if uiImage == nil && retryCount < maxRetries {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if self.uiImage == nil {
                            self.retryCount += 1
                            self.imageLoadAttempted = false
                            self.loadImageIfNeeded()
                        }
                    }
                }
            }
        }
        .onChange(of: smilie.objectID) { _ in
            // Reset state when smilie changes
            uiImage = nil
            imageLoadAttempted = false
            retryCount = 0
            if !shouldUseAnimatedView {
                loadImageIfNeeded()
            }
        }
    }
    
    private var backgroundColorForIcon: Color {
        // Subtle background for the icon area
        if theme.isDark {
            return theme[color: "sheetTextColor"]?.opacity(0.25) ?? Color.white.opacity(0.25)
        } else {
            return theme[color: "listSeparatorColor"]?.opacity(0.2) ?? Color.black.opacity(0.1)
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.3))
            Text(smilie.text)
                .font(.system(size: 9))
                .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.5))
                .lineLimit(1)
        }
        .frame(width: itemSize - 16, height: itemSize - 16)
    }
    
    private func loadImageIfNeeded() {
        // Skip loading for GIFs - they'll be handled by AnimatedImageView
        if shouldUseAnimatedView {
            imageLoadAttempted = true
            return
        }
        
        guard !imageLoadAttempted, let imageData = smilie.imageData else {
            return
        }
        
        imageLoadAttempted = true
        
        // Load image on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.uiImage = image
                }
            } else {
                // Try alternative loading method
                if let cgImageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) {
                    let image = UIImage(cgImage: cgImage)
                    DispatchQueue.main.async {
                        self.uiImage = image
                    }
                } else {
                    // Both loading methods failed
                    DispatchQueue.main.async {
                        self.imageLoadAttempted = true
                    }
                    print("SmilieGridItem: Failed to load image for \(smilie.text ?? "")")
                }
            }
        }
    }
}

struct SmilieButtonStyle: ButtonStyle {
    @SwiftUI.Environment(\.theme) private var theme: Theme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#if DEBUG
struct SmilieGridItem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            SmiliePickerView(dataStore: .shared) { smilie in
                print("Selected: \(smilie.text ?? "")")
            }
            .environment(\.theme, Theme.defaultTheme())
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            SmiliePickerView(dataStore: .shared) { smilie in
                print("Selected: \(smilie.text ?? "")")
            }
            .environment(\.theme, Theme.theme(named: "dark")!)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
