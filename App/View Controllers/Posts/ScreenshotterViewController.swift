//  ScreenshotterViewController.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import MRProgress
import os
import Smilies
import SwiftUI
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Screenshotter")

/// Full-screen view controller for selecting posts to screenshot.
final class ScreenshotterViewController: ViewController {

    private let posts: [Post]
    private let sourceTheme: Theme
    private var hostingController: UIViewController?

    init(posts: [Post], theme: Theme) {
        self.posts = posts
        self.sourceTheme = theme
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewModel = ScreenshotterViewModel(posts: posts, theme: sourceTheme)
        let screenshotterView = ScreenshotterView(
            viewModel: viewModel,
            onCancel: { [weak self] in self?.dismiss(animated: true) }
        )
        .themed()

        let hc = UIHostingController(rootView: screenshotterView)
        addChild(hc)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hc.view)
        hc.didMove(toParent: self)
        hostingController = hc
    }
}

// MARK: - View Model

@MainActor
final class ScreenshotterViewModel: ObservableObject {
    let posts: [Post]
    let theme: Theme

    @Published var selectedIndices: [Int] = []
    @Published var thumbnails: [Int: UIImage] = [:]
    @Published var isGeneratingScreenshot = false
    @Published var isLoadingThumbnails = true
    @Published var generatedImage: UIImage?

    init(posts: [Post], theme: Theme) {
        self.posts = posts
        self.theme = theme
    }

    func loadThumbnails() async {
        isLoadingThumbnails = true

        await PostScreenshotter.renderThumbnails(
            for: posts, theme: theme, width: 375, maxHeight: 300
        ) { index, image in
            thumbnails[index] = image
        }

        isLoadingThumbnails = false
    }

    func toggleSelection(at index: Int) {
        if let existing = selectedIndices.firstIndex(of: index) {
            selectedIndices.remove(at: existing)
        } else {
            selectedIndices.append(index)
        }
    }

    func selectionOrder(for index: Int) -> Int? {
        selectedIndices.firstIndex(of: index).map { $0 + 1 }
    }

    func generateScreenshot() async {
        guard !selectedIndices.isEmpty else { return }
        isGeneratingScreenshot = true
        defer { isGeneratingScreenshot = false }

        let selectedPosts = selectedIndices.map { posts[$0] }
        do {
            generatedImage = try await PostScreenshotter.renderScreenshot(
                for: selectedPosts, theme: theme, width: 375
            )
        } catch {
            logger.error("failed to generate screenshot: \(error)")
        }
    }
}

// MARK: - Annotation Model

final class AnnotationItem: ObservableObject, Identifiable {
    let id = UUID()
    @Published var content: Content
    @Published var offset: CGSize = .zero
    @Published var scale: CGFloat = 1.0
    @Published var rotation: Angle = .zero

    enum Content {
        case text(String, UIColor)
        case smilie(UIImage)
        case watermark(UIImage)
    }

    var isText: Bool {
        if case .text = content { return true }
        return false
    }

    init(content: Content, offset: CGSize = .zero) {
        self.content = content
        self.offset = offset
    }
}

// MARK: - Post Selection Grid

struct ScreenshotterView: View {
    @ObservedObject var viewModel: ScreenshotterViewModel
    let onCancel: () -> Void

    @SwiftUI.Environment(\.theme) var theme
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showingPreview = false

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationView {
            ZStack {
                (theme[color: "backgroundColor"] ?? Color(.systemBackground))
                    .ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<viewModel.posts.count, id: \.self) { index in
                            PostThumbnailCell(
                                thumbnail: viewModel.thumbnails[index],
                                selectionNumber: viewModel.selectionOrder(for: index),
                                username: viewModel.posts[index].author?.username ?? "Unknown",
                                onTap: { viewModel.toggleSelection(at: index) }
                            )
                        }
                    }
                    .padding()
                }

            }
            .onChange(of: viewModel.isGeneratingScreenshot) { generating in
                if generating {
                    showMRProgress(title: "Generating screenshot…")
                } else {
                    dismissMRProgress()
                }
            }
            .navigationTitle("Screenshot Posts")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(theme.isDark ? .dark : .light)
            .background(NavigationConfigurator(theme: theme))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Screenshot") {
                        Task {
                            await viewModel.generateScreenshot()
                            if viewModel.generatedImage != nil { showingPreview = true }
                        }
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                    .disabled(viewModel.selectedIndices.isEmpty || viewModel.isGeneratingScreenshot)
                }
            }
            .fullScreenCover(isPresented: $showingPreview) {
                if let image = viewModel.generatedImage {
                    ScreenshotPreviewView(
                        image: image,
                        isDark: viewModel.theme.isDark,
                        onDone: {
                            showingPreview = false
                            viewModel.generatedImage = nil
                        }
                    )
                    .themed()
                }
            }
        }
        .navigationViewStyle(.stack)
        .task { await viewModel.loadThumbnails() }
    }

    private func showMRProgress(title: String) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else { return }
        MRProgressOverlayView.showOverlayAdded(to: window, title: title, mode: .indeterminate, animated: true)
    }

    private func dismissMRProgress() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else { return }
        MRProgressOverlayView.dismissAllOverlays(for: window, animated: true)
    }
}

// MARK: - Screenshot Preview with Annotations

struct ScreenshotPreviewView: View {
    let image: UIImage
    let isDark: Bool
    let onDone: () -> Void

    @SwiftUI.Environment(\.theme) var theme
    @State private var annotations: [AnnotationItem] = []
    @State private var selectedAnnotationID: UUID?
    @State private var showingTextInput = false
    @State private var showingSmiliePicker = false
    @State private var textInputValue = ""
    @State private var imageSize: CGSize = .zero

    var body: some View {
        NavigationView {
            ZStack {
                (theme[color: "backgroundColor"] ?? Color(.systemBackground))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    GeometryReader { _ in
                        ScrollView {
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .background(GeometryReader { imgGeo in
                                        Color.clear.onAppear { imageSize = imgGeo.size }
                                            .onChange(of: imgGeo.size) { imageSize = $0 }
                                    })

                                ForEach(annotations) { annotation in
                                    AnnotationOverlayView(
                                        annotation: annotation,
                                        isSelected: selectedAnnotationID == annotation.id,
                                        onSelect: { selectedAnnotationID = annotation.id },
                                        onDelete: { annotations.removeAll { $0.id == annotation.id }; selectedAnnotationID = nil }
                                    )
                                }
                            }
                            .frame(maxWidth: 500)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedAnnotationID = nil }
                            .padding()
                        }
                    }

                    if let selected = annotations.first(where: { $0.id == selectedAnnotationID }), selected.isText {
                        TextColorPalette(annotation: selected)
                            .padding(.bottom, 4)
                    }
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(theme.isDark ? .dark : .light)
            .background(NavigationConfigurator(theme: theme))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { showingTextInput = true } label: {
                        Label("Add Text", systemImage: "textformat")
                    }
                    .foregroundColor(theme[color: "sheetTextColor"])

                    Button { showingSmiliePicker = true } label: {
                        Label("Add Smilie", systemImage: "face.smiling")
                    }
                    .foregroundColor(theme[color: "sheetTextColor"])

                    Spacer()

                    Button {
                        presentShareSheet()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(theme[color: "sheetTextColor"])
                }
            }
            .alert("Add Text", isPresented: $showingTextInput) {
                TextField("Enter text", text: $textInputValue)
                Button("Add") {
                    guard !textInputValue.isEmpty else { return }
                    let color: UIColor = isDark ? .white : .black
                    annotations.append(AnnotationItem(content: .text(textInputValue, color)))
                    textInputValue = ""
                }
                Button("Cancel", role: .cancel) { textInputValue = "" }
            }
            .sheet(isPresented: $showingSmiliePicker) {
                SmiliePickerView(dataStore: .shared) { smilie in
                    if let data = smilie.imageData, let img = UIImage(data: data) {
                        annotations.append(AnnotationItem(content: .smilie(img)))
                    }
                    showingSmiliePicker = false
                }
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: imageSize) { newSize in
            guard !annotations.contains(where: { if case .watermark = $0.content { return true }; return false }),
                  newSize.width > 0 else { return }
            let watermarkImage = PostScreenshotter.renderWatermark(isDark: isDark)
            let item = AnnotationItem(content: .watermark(watermarkImage))
            let margin: CGFloat = 12
            item.offset = CGSize(
                width: newSize.width / 2 - watermarkImage.size.width / 2 - margin,
                height: newSize.height / 2 - watermarkImage.size.height * 2.5 - margin
            )
            annotations.append(item)
        }
    }

    private func presentShareSheet() {
        let composited = compositeImage()
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else { return }

        // Walk to the topmost presented view controller
        var presenter = window.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        guard let presenter else { return }

        let activityVC = UIActivityViewController(activityItems: [composited], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed { showSavedOverlay() }
        }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }

    private func showSavedOverlay() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else { return }

        let overlay = MRProgressOverlayView.showOverlayAdded(to: window, title: "Saved", mode: .checkmark, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            overlay?.dismiss(true)
        }
    }

    // MARK: - Compositing

    private func compositeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { ctx in
            image.draw(at: .zero)

            let scaleX = image.size.width / max(imageSize.width, 1)
            let scaleY = image.size.height / max(imageSize.height, 1)
            let centerX = image.size.width / 2
            let centerY = image.size.height / 2

            for annotation in annotations {
                let offsetX = annotation.offset.width * scaleX
                let offsetY = annotation.offset.height * scaleY
                let drawCenter = CGPoint(x: centerX + offsetX, y: centerY + offsetY)
                let rotationRadians = CGFloat(annotation.rotation.radians)

                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: drawCenter.x, y: drawCenter.y)
                ctx.cgContext.rotate(by: rotationRadians)

                switch annotation.content {
                case .text(let text, let color):
                    let fontSize = 24 * annotation.scale * scaleX
                    let font = UIFont.boldSystemFont(ofSize: fontSize)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                    ]
                    let textSize = (text as NSString).size(withAttributes: attrs)
                    (text as NSString).draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2), withAttributes: attrs)

                case .smilie(let smilieImage):
                    let baseSize = CGSize(width: smilieImage.size.width * 3, height: smilieImage.size.height * 3)
                    let w = baseSize.width * annotation.scale * scaleX
                    let h = baseSize.height * annotation.scale * scaleY
                    ctx.cgContext.interpolationQuality = .none
                    smilieImage.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                    ctx.cgContext.interpolationQuality = .default

                case .watermark(let wmImage):
                    let w = wmImage.size.width * annotation.scale * scaleX
                    let h = wmImage.size.height * annotation.scale * scaleY
                    wmImage.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                }

                ctx.cgContext.restoreGState()
            }
        }
    }
}

// MARK: - Annotation Overlay View

struct AnnotationOverlayView: View {
    @ObservedObject var annotation: AnnotationItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var twistRotation: Angle = .zero

    private let handleSize: CGFloat = 26

    var body: some View {
        annotationContent
            .overlay(selectionBorder)
            .scaleEffect(annotation.scale * pinchScale)
            .rotationEffect(annotation.rotation + twistRotation)
            .offset(x: annotation.offset.width + dragOffset.width,
                    y: annotation.offset.height + dragOffset.height)
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .gesture(rotationGesture)
            .onTapGesture { onSelect() }
    }

    @ViewBuilder
    private var annotationContent: some View {
        switch annotation.content {
        case .text(let text, let color):
            Text(text)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(color))
                .fixedSize()

        case .smilie(let image):
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: image.size.width * 3, height: image.size.height * 3)

        case .watermark(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: image.size.width, height: image.size.height)
        }
    }

    @ViewBuilder
    private var selectionBorder: some View {
        if isSelected {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5 / max(annotation.scale, 0.1), dash: [6]))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: handleSize * 0.8))
                        .foregroundStyle(.white, .red)
                }
                .position(x: 0, y: 0)

                ResizeHandleView(annotation: annotation)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: w, y: 0)

                ResizeHandleView(annotation: annotation)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: 0, y: h)

                RotateHandleView(annotation: annotation)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: w, y: h)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation }
            .onEnded { value in
                annotation.offset.width += value.translation.width
                annotation.offset.height += value.translation.height
                dragOffset = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in pinchScale = value }
            .onEnded { value in
                annotation.scale *= value
                pinchScale = 1.0
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in twistRotation = value }
            .onEnded { value in
                annotation.rotation += value
                twistRotation = .zero
            }
    }
}

// MARK: - Resize Handle (top-right, bottom-left)

struct ResizeHandleView: View {
    @ObservedObject var annotation: AnnotationItem

    @State private var initialScale: CGFloat?

    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 2)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let startScale = initialScale ?? annotation.scale
                        if initialScale == nil { initialScale = annotation.scale }
                        let delta = (value.translation.width + value.translation.height) / 2
                        let sensitivity: CGFloat = 0.01
                        annotation.scale = max(0.2, startScale + delta * sensitivity)
                    }
                    .onEnded { _ in initialScale = nil }
            )
    }
}

// MARK: - Rotate Handle (bottom-right)

struct RotateHandleView: View {
    @ObservedObject var annotation: AnnotationItem

    @State private var initialRotation: Angle?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 2)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let startRotation = initialRotation ?? annotation.rotation
                    if initialRotation == nil { initialRotation = annotation.rotation }
                    let degrees = value.translation.width * 0.5
                    annotation.rotation = startRotation + .degrees(degrees)
                }
                .onEnded { _ in initialRotation = nil }
        )
    }
}

// MARK: - Text Color Palette

struct TextColorPalette: View {
    @ObservedObject var annotation: AnnotationItem

    private let colors: [(String, UIColor)] = [
        ("White", .white),
        ("Black", .black),
        ("Red", .systemRed),
        ("Orange", .systemOrange),
        ("Yellow", .systemYellow),
        ("Green", .systemGreen),
        ("Blue", .systemBlue),
        ("Purple", .systemPurple),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.0) { (name, color) in
                Button {
                    if case .text(let text, _) = annotation.content {
                        annotation.content = .text(text, color)
                    }
                } label: {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Post Thumbnail Cell

struct PostThumbnailCell: View {
    let thumbnail: UIImage?
    let selectionNumber: Int?
    let username: String
    let onTap: () -> Void

    @SwiftUI.Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 4) {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                            .overlay(ProgressView())
                    }

                    Text(username)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(theme[color: "listSecondaryTextColor"] ?? .secondary)
                }

                if let selectionNumber {
                    Text("\(selectionNumber)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(theme[color: "tintColor"] ?? Color.accentColor))
                        .offset(x: -4, y: -24)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectionNumber != nil ? (theme[color: "tintColor"] ?? Color.accentColor) : Color.clear, lineWidth: 3)
                .padding(.bottom, 20)
        )
    }
}
