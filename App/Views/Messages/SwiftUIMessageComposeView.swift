//  SwiftUIMessageComposeView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import Nuke
import SwiftUI
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SwiftUIMessageComposeView")

struct SwiftUIMessageComposeView: View {
    let recipient: User?
    let regardingMessage: PrivateMessage?
    let forwardingMessage: PrivateMessage?
    let initialContents: String?
    
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MessageComposeViewModel
    @State private var showingThreadTagPicker = false
    
    init(
        recipient: User? = nil,
        regardingMessage: PrivateMessage? = nil,
        forwardingMessage: PrivateMessage? = nil,
        initialContents: String? = nil
    ) {
        self.recipient = recipient
        self.regardingMessage = regardingMessage
        self.forwardingMessage = forwardingMessage
        self.initialContents = initialContents
        
        self._viewModel = StateObject(wrappedValue: MessageComposeViewModel(
            recipient: recipient,
            regardingMessage: regardingMessage,
            forwardingMessage: forwardingMessage,
            initialContents: initialContents
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationHeaderView(
                title: "Private Message",
                leftButton: HeaderButton(text: "Cancel") {
                    cancelCompose()
                },
                rightButton: HeaderButton(text: viewModel.isSubmitting ? "Sending..." : "Send") {
                    submitMessage()
                }
            )
            
            VStack(spacing: 0) {
                // Header fields
                messageHeaderFields
                
                // Message content
                messageContentEditor
            }
        }
        .onAppear {
            viewModel.setupInitialValues()
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .sheet(isPresented: $showingThreadTagPicker) {
            if let picker = viewModel.threadTagPicker {
                ThreadTagPickerWrapper(picker: picker, onDismiss: {
                    showingThreadTagPicker = false
                })
                .presentationDetents([.medium, .large])
            }
        }
        .themed()
    }
    
    private var messageHeaderFields: some View {
        VStack(spacing: 0) {
            // Thread tag, To, and Subject fields
            HStack(spacing: 0) {
                // Thread tag button
                Button(action: {
                    showThreadTagPicker()
                }) {
                    if let tagImage = viewModel.threadTagImage {
                        Image(uiImage: tagImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "tag")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 54)
                .disabled(!viewModel.threadTagsLoaded)
                
                VStack(spacing: 0) {
                    // To field
                    HStack {
                        Text("To")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Username", text: $viewModel.toField)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 16))
                            .foregroundColor(Color(theme[uicolor: "listTextColor"] ?? UIColor.label))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 44)
                    
                    Divider()
                        .background(Color(theme[uicolor: "listSeparatorColor"] ?? UIColor.separator))
                    
                    // Subject field
                    HStack {
                        Text("Subject")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Subject", text: $viewModel.subjectField)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .foregroundColor(Color(theme[uicolor: "listTextColor"] ?? UIColor.label))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 44)
                }
            }
            
            Divider()
                .background(Color(theme[uicolor: "listSeparatorColor"] ?? UIColor.separator))
        }
        .background(Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground))
    }
    
    private var messageContentEditor: some View {
        VStack(spacing: 0) {
            TextEditor(text: $viewModel.messageText)
                .font(.system(size: 16))
                .foregroundColor(Color(theme[uicolor: "listTextColor"] ?? UIColor.label))
                .background(Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground))
                .scrollContentBackground(.hidden)
        }
        .background(Color(theme[uicolor: "listBackgroundColor"] ?? UIColor.systemBackground))
    }
    
    // MARK: - Actions
    
    private func cancelCompose() {
        if viewModel.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dismiss()
    }
    
    private func submitMessage() {
        guard viewModel.canSubmit && !viewModel.isSubmitting else { return }
        
        if viewModel.enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        Task {
            let success = await viewModel.submitMessage()
            if success {
                dismiss()
            }
        }
    }
    
    private func showThreadTagPicker() {
        Task {
            await viewModel.loadThreadTagsIfNeeded()
            if viewModel.threadTagPicker != nil {
                showingThreadTagPicker = true
            }
        }
    }
}

// MARK: - Thread Tag Picker Wrapper

struct ThreadTagPickerWrapper: UIViewControllerRepresentable {
    let picker: ThreadTagPickerViewController
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let navController = UINavigationController(rootViewController: picker)
        picker.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: context.coordinator,
            action: #selector(Coordinator.dismiss)
        )
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        @objc func dismiss() {
            onDismiss()
        }
    }
}

struct SwiftUIMessageComposeView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIMessageComposeView()
            .themed()
    }
}