//  SmilieGridItem.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import os
import SwiftUI
import Smilies
import UniformTypeIdentifiers
import AwfulTheming

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SmilieGridItem")

struct SmilieGridItem: View {
    @ObservedObject var smilie: Smilie
    let onTap: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme: Theme

    /// The decoded still image for `smilie.imageData`. Each decoded case remembers the data it
    /// came from so a cell scrolling back on screen doesn't decode (or show a spinner) again.
    private enum DecodedImage {
        case pending
        case image(UIImage, source: Data)
        case failed(source: Data)

        var source: Data? {
            switch self {
            case .pending: nil
            case .image(_, let source), .failed(let source): source
            }
        }
    }
    @State private var decoded: DecodedImage = .pending
    
    private let itemSize: CGFloat = 90
    
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
                            } else {
                                switch decoded {
                                case .image(let uiImage, _):
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .interpolation(.none)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: itemSize - 16, maxHeight: itemSize - 16)
                                        .clipped()
                                case .failed:
                                    placeholderView
                                case .pending:
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: itemSize - 16, height: itemSize - 16)
                                }
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
        // Keyed on the bytes the decode consumes (the grid already keys the cell itself by
        // smilie). Leaving the grid cancels the task; scrolling back re-runs it, which the
        // `source` check turns into a no-op.
        .task(id: smilie.imageData) {
            // GIFs are handled by AnimatedImageView.
            guard !shouldUseAnimatedView, let imageData = smilie.imageData else { return }
            guard decoded.source != imageData else { return }
            if decoded.source != nil {
                decoded = .pending
            }
            let image = await Self.decodeImage(imageData)
            // A finished decode is worth keeping even if this task was cancelled meanwhile;
            // only drop it if the data changed underneath.
            guard smilie.imageData == imageData else { return }
            if let image {
                decoded = .image(image, source: imageData)
            } else {
                logger.error("failed to decode image for \(smilie.text ?? "")")
                decoded = .failed(source: imageData)
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
    
    /// Decodes and pre-renders a still image on the global executor, off the main actor that
    /// `View` members are isolated to.
    @concurrent nonisolated private static func decodeImage(_ imageData: Data) async -> UIImage? {
        let image: UIImage?
        if let direct = UIImage(data: imageData) {
            image = direct
        } else if
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            image = UIImage(cgImage: cgImage)
        } else {
            image = nil
        }
        // UIImage decodes lazily at draw time on the main thread; force it here instead.
        return image?.preparingForDisplay() ?? image
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
