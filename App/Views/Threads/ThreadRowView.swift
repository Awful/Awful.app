//  ThreadRowView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import AwfulCore
import AwfulTheming
import Nuke
import NukeExtensions
import SwiftUI
import UIKit

struct ThreadRowView: View {
    let viewModel: ThreadRowViewModel
    let onTap: () -> Void
    let onBookmarkToggle: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    @State private var tagImage: UIImage?
    @State private var secondaryTagImage: UIImage?
    @State private var tagImageTask: ImageTask?
    @State private var secondaryTagImageTask: ImageTask?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Tag and rating images
                if viewModel.showTagAndRating {
                    VStack(spacing: 2) {
                        // Tag image
                        if let tagImage = tagImage {
                            Image(uiImage: tagImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(alignment: .topTrailing) {
                                    // Secondary tag overlay
                                    if let secondaryTagImage = secondaryTagImage {
                                        Image(uiImage: secondaryTagImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 14, height: 14)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                                .frame(width: 40, height: 40)
                        }
                        
                        // Rating image
                        if let ratingImage = viewModel.ratingImage {
                            Image(uiImage: ratingImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 12)
                        }
                    }
                    .frame(width: 46)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(viewModel.title)
                        .font(Font(viewModel.titleFont))
                        .foregroundColor(viewModel.titleColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                    
                    // Page count, page icon, post info
                    HStack(spacing: 2) {
                        // Page count
                        Text(viewModel.pageCount)
                            .font(Font(viewModel.pageCountFont))
                            .foregroundColor(viewModel.pageCountColor)
                        
                        // Page icon
                        Image("page")
                            .renderingMode(.template)
                            .foregroundColor(viewModel.pageIconColor)
                            .frame(width: 9, height: 12)
                        
                        // Post info
                        Text(viewModel.postInfo)
                            .font(Font(viewModel.postInfoFont))
                            .foregroundColor(viewModel.postInfoColor)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Unread count
                if !viewModel.unreadCount.isEmpty {
                    Text(viewModel.unreadCount)
                        .font(Font(viewModel.unreadCountFont))
                        .foregroundColor(viewModel.unreadCountColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(viewModel.unreadCountColor.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 72)
            .background(viewModel.backgroundColor)
            .overlay(alignment: .topTrailing) {
                // Sticky indicator
                if let stickyImage = viewModel.stickyImage {
                    Image(uiImage: stickyImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .buttonStyle(ThreadRowButtonStyle(selectedBackgroundColor: viewModel.selectedBackgroundColor))
        .onAppear {
            loadTagImages()
        }
        .onChange(of: viewModel.tagImageName) { _ in
            loadTagImages()
        }
        .onDisappear {
            tagImageTask?.cancel()
            secondaryTagImageTask?.cancel()
        }
        .contextMenu {
            ThreadContextMenu(
                onBookmarkToggle: onBookmarkToggle
            )
        }
    }
    
    private func loadTagImages() {
        // Cancel any existing tasks
        tagImageTask?.cancel()
        secondaryTagImageTask?.cancel()
        
        // Load main tag image
        if let tagImageName = viewModel.tagImageName {
            tagImageTask = ThreadTagLoader.shared.loadImage(named: tagImageName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        self.tagImage = response.image
                    case .failure:
                        // Use placeholder if available
                        self.tagImage = viewModel.tagImagePlaceholder?.image
                    }
                }
            }
        } else {
            // Use placeholder if no tag image name
            tagImage = viewModel.tagImagePlaceholder?.image
        }
        
        // Load secondary tag image
        if let secondaryTagImageName = viewModel.secondaryTagImageName {
            secondaryTagImageTask = ThreadTagLoader.shared.loadImage(named: secondaryTagImageName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        self.secondaryTagImage = response.image
                    case .failure:
                        self.secondaryTagImage = nil
                    }
                }
            }
        } else {
            secondaryTagImage = nil
        }
    }
}

struct ThreadRowButtonStyle: ButtonStyle {
    let selectedBackgroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? selectedBackgroundColor : Color.clear
            )
    }
}

struct ThreadContextMenu: View {
    let onBookmarkToggle: () -> Void
    
    var body: some View {
        Button(action: onBookmarkToggle) {
            Label("Toggle Bookmark", systemImage: "bookmark")
        }
    }
}

struct ThreadRowView_Previews: PreviewProvider {
    static var previews: some View {
        ThreadRowView(
            viewModel: ThreadRowViewModel.empty,
            onTap: {},
            onBookmarkToggle: {}
        )
        .themed()
    }
}
