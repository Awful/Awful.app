//  MessageComposeViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Combine
import Foundation
import Nuke
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageComposeViewModel")

@MainActor
final class MessageComposeViewModel: ObservableObject {
    @Published var toField = ""
    @Published var subjectField = ""
    @Published var messageText = ""
    @Published var canSubmit = false
    @Published var isSubmitting = false
    @Published var showingError = false
    @Published var threadTagImage: UIImage?
    @Published var threadTagsLoaded = false
    
    var error: Error?
    var threadTagPicker: ThreadTagPickerViewController?
    
    private let recipient: User?
    private let regardingMessage: PrivateMessage?
    private let forwardingMessage: PrivateMessage?
    private let initialContents: String?
    
    private var selectedThreadTag: ThreadTag?
    private var availableThreadTags: [ThreadTag]?
    private var threadTagImageTask: ImageTask?
    private var cancellables: Set<AnyCancellable> = []
    private var threadTagPickerDelegate: ThreadTagPickerDelegate?
    
    @FoilDefaultStorage(Settings.enableHaptics) var enableHaptics
    
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
        
        setupValidation()
        updateThreadTagImage()
    }
    
    private func setupValidation() {
        // Combine validation for submit button
        Publishers.CombineLatest3($toField, $subjectField, $messageText)
            .map { to, subject, message in
                !to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .assign(to: &$canSubmit)
    }
    
    func setupInitialValues() {
        // Set up initial field values
        if let recipient = recipient {
            toField = recipient.username ?? ""
        } else if let regardingMessage = regardingMessage {
            toField = regardingMessage.from?.username ?? ""
            
            var subject = regardingMessage.subject ?? ""
            if !subject.hasPrefix("Re: ") {
                subject = "Re: \(subject)"
            }
            subjectField = subject
            
            if let initialContents = initialContents {
                messageText = initialContents
            }
        } else if let forwardingMessage = forwardingMessage {
            subjectField = "Fw: \(forwardingMessage.subject ?? "")"
            
            if let initialContents = initialContents {
                messageText = initialContents
            }
        }
        
        // Start loading thread tags
        Task {
            await loadThreadTagsIfNeeded()
        }
    }
    
    func loadThreadTagsIfNeeded() async {
        guard availableThreadTags?.isEmpty ?? true else {
            threadTagsLoaded = true
            return
        }
        
        do {
            let threadTags = try await ForumsClient.shared.listAvailablePrivateMessageThreadTags()
            availableThreadTags = threadTags
            
            let picker = ThreadTagPickerViewController(
                firstTag: .privateMessage,
                imageNames: threadTags.compactMap { $0.imageName },
                secondaryImageNames: []
            )
            let delegate = ThreadTagPickerDelegate(viewModel: self)
            picker.delegate = delegate
            threadTagPickerDelegate = delegate
            threadTagPicker = picker
            threadTagsLoaded = true
        } catch {
            logger.error("Could not list available private message thread tags: \(error)")
            threadTagsLoaded = false
        }
    }
    
    private func updateThreadTagImage() {
        threadTagImageTask?.cancel()
        
        guard let threadTag = selectedThreadTag else {
            threadTagImage = ThreadTagLoader.Placeholder.thread(tintColor: nil).image
            return
        }
        
        threadTagImageTask = ThreadTagLoader.shared.loadImage(named: threadTag.imageName) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.threadTagImage = response.image
                case .failure:
                    self?.threadTagImage = ThreadTagLoader.Placeholder.thread(tintColor: nil).image
                }
            }
        }
    }
    
    func selectThreadTag(imageName: String?) {
        if let imageName = imageName,
           let availableThreadTags = availableThreadTags,
           let tag = availableThreadTags.first(where: { $0.imageName == imageName }) {
            selectedThreadTag = tag
        } else {
            selectedThreadTag = nil
        }
        updateThreadTagImage()
    }
    
    func submitMessage() async -> Bool {
        let to = toField.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = subjectField.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !to.isEmpty, !subject.isEmpty, !message.isEmpty else {
            return false
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            let relevant: ForumsClient.RelevantMessage
            if let regardingMessage = regardingMessage {
                relevant = .replyingTo(regardingMessage)
            } else if let forwardingMessage = forwardingMessage {
                relevant = .forwarding(forwardingMessage)
            } else {
                relevant = .none
            }
            
            try await ForumsClient.shared.sendPrivateMessage(
                to: to,
                subject: subject,
                threadTag: selectedThreadTag,
                bbcode: message,
                about: relevant
            )
            
            return true
        } catch {
            self.error = error
            self.showingError = true
            return false
        }
    }
}

// MARK: - Thread Tag Picker Delegate

private class ThreadTagPickerDelegate: NSObject, ThreadTagPickerViewControllerDelegate {
    weak var viewModel: MessageComposeViewModel?
    
    init(viewModel: MessageComposeViewModel) {
        self.viewModel = viewModel
    }
    
    func didSelectImageName(_ imageName: String?, in picker: ThreadTagPickerViewController) {
        Task { @MainActor in
            viewModel?.selectThreadTag(imageName: imageName)
        }
        picker.dismiss()
    }
    
    func didSelectSecondaryImageName(_ secondaryImageName: String, in picker: ThreadTagPickerViewController) {
        // Not used for private messages
    }
    
    func didDismissPicker(_ picker: ThreadTagPickerViewController) {
        // Handle dismissal if needed
    }
}