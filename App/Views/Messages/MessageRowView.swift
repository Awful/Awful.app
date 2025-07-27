//  MessageRowView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Nuke
import NukeExtensions
import SwiftUI
import UIKit

struct MessageRowView: View {
    let viewModel: MessageRowViewModel
    let onTap: () -> Void
    let message: PrivateMessage?
    
    @SwiftUI.Environment(\.theme) private var theme
    @State private var tagImage: UIImage?
    @State private var tagImageTask: ImageTask?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Tag image
                if viewModel.showThreadTags {
                    VStack {
                        if let tagImage = tagImage {
                            Image(uiImage: tagImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(alignment: .topTrailing) {
                                    // Overlay for replied/forwarded/unread status
                                    if let overlayImage = viewModel.overlayImage {
                                        Image(uiImage: overlayImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 18, height: 18)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .frame(width: 46)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    // Sender name
                    Text(viewModel.sender)
                        .font(Font(viewModel.senderFont))
                        .foregroundColor(viewModel.senderColor)
                        .lineLimit(1)
                    
                    // Subject
                    Text(viewModel.subject)
                        .font(Font(viewModel.subjectFont))
                        .foregroundColor(viewModel.subjectColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                }
                
                Spacer()
                
                // Date
                Text(viewModel.sentDate)
                    .font(Font(viewModel.sentDateFont))
                    .foregroundColor(viewModel.sentDateColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 65)
            .background(viewModel.backgroundColor)
        }
        .buttonStyle(MessageRowButtonStyle(selectedBackgroundColor: viewModel.selectedBackgroundColor))
        .onAppear {
            loadTagImage()
        }
        .onChange(of: viewModel.tagImageName) { _ in
            loadTagImage()
        }
        .onDisappear {
            tagImageTask?.cancel()
        }
        .contextMenu {
            if let message = message {
                MessageContextMenu(
                    message: message,
                    onDelete: { deleteMessage() }
                )
            }
        }
    }
    
    private func loadTagImage() {
        // Cancel any existing task
        tagImageTask?.cancel()
        
        // Load tag image
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
    }
    
    private func deleteMessage() {
        guard let message = message else { return }
        NotificationCenter.default.post(name: Notification.Name("DeleteMessage"), object: message)
    }
}

struct MessageRowButtonStyle: ButtonStyle {
    let selectedBackgroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? selectedBackgroundColor : Color.clear
            )
    }
}

struct MessageContextMenu: View {
    let message: PrivateMessage
    let onDelete: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct MessageRowView_Previews: PreviewProvider {
    static var previews: some View {
        MessageRowView(
            viewModel: MessageRowViewModel.empty,
            onTap: {},
            message: nil
        )
        .themed()
    }
}