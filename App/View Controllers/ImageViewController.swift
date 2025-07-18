//  ImageViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UIKit

// MARK: - SwiftUI Image Viewer
struct SwiftUIImageViewer: View {
    let imageURL: URL
    
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showingActionSheet = false
    @State private var showingOverlay = true
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastIcon: String = "checkmark"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Image content
                if let image = image {
                    imageView(image: image, in: geometry)
                } else if isLoading {
                    loadingView
                } else if loadError != nil {
                    errorView
                }
                
                // Overlay controls
                if showingOverlay {
                    overlayView
                }
                
                // Toast notification
                if showingToast {
                    toastView
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingOverlay.toggle()
            }
        }
        .confirmationDialog("Image Actions", isPresented: $showingActionSheet) {
            imageActionButtons
        }
    }
    
    private func imageView(image: UIImage, in geometry: GeometryProxy) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.5, min(5.0, value))
                        },
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                offset = .zero
                            }
                        }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                    } else {
                        scale = 2.0
                    }
                }
            }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading...")
                .foregroundColor(.white)
                .padding(.top)
        }
    }
    
    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.white)
                .font(.system(size: 48))
            
            Text("Failed to load image")
                .foregroundColor(.white)
                .padding(.top)
        }
    }
    
    private var overlayView: some View {
        VStack {
            HStack {
                Spacer()
                
                // Done button with checkmark (blue)
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                        )
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 16)
            
            Spacer()
            
            HStack {
                Spacer()
                
                // Action button (matches original ImageViewController)
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 32, height: 32)
                        )
                }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }
    
    // MARK: - Action Buttons
    private var imageActionButtons: some View {
        Group {
            // Copy URL
            Button("Copy URL") {
                copyURL()
            }
            
            // Copy Image
            if self.image != nil {
                Button("Copy Image") {
                    copyImage()
                }
            }
            
            // Save to Photos
            if self.image != nil {
                Button("Save to Photos") {
                    saveToPhotos()
                }
            }
            
            // Share
            if self.image != nil {
                Button("Share") {
                    shareImage()
                }
            }
            
            Button("Cancel", role: .cancel) {
                // Cancel action
            }
        }
    }
    
    // MARK: - Toast View
    private var toastView: some View {
        HStack {
            Image(systemName: toastIcon)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold))
            
            Text(toastMessage)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
        )
        .transition(.opacity.combined(with: .scale))
    }
    
    private func loadImage() {
        isLoading = true
        loadError = nil
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                
                await MainActor.run {
                    if let loadedImage = UIImage(data: data) {
                        self.image = loadedImage
                        self.isLoading = false
                    } else {
                        self.loadError = NSError(domain: "ImageLoadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Action Methods
    private func copyURL() {
        UIPasteboard.general.string = imageURL.absoluteString
        showToast(message: "URL copied", icon: "link")
    }
    
    private func copyImage() {
        guard let currentImage = image else { return }
        UIPasteboard.general.image = currentImage
        showToast(message: "Image copied", icon: "checkmark")
    }
    
    private func saveToPhotos() {
        guard let currentImage = image else { return }
        
        UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
        showToast(message: "Image saved to Photos", icon: "checkmark")
    }
    
    private func shareImage() {
        guard let currentImage = image else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [currentImage, imageURL],
            applicationActivities: nil
        )
        
        // Find the root view controller to present from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Handle iPad popover
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func showToast(message: String, icon: String) {
        toastMessage = message
        toastIcon = icon
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingToast = true
        }
        
        // Hide toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingToast = false
            }
        }
    }
}

