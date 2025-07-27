//  MessageRowViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import SwiftUI
import UIKit

struct MessageRowViewModel: Identifiable {
    let id: String
    let backgroundColor: Color
    let selectedBackgroundColor: Color
    let sender: String
    let senderColor: Color
    let senderFont: UIFont
    let sentDate: String
    let sentDateColor: Color
    let sentDateFont: UIFont
    let subject: String
    let subjectColor: Color
    let subjectFont: UIFont
    let tagImageName: String?
    let tagImagePlaceholder: ThreadTagLoader.Placeholder?
    let overlayImage: UIImage?
    let showThreadTags: Bool
    let isUnread: Bool
    let isReplied: Bool
    let isForwarded: Bool
    
    init(message: PrivateMessage, theme: Theme, showsThreadTags: Bool) {
        self.id = message.messageID
        self.backgroundColor = Color(theme[uicolor: "listBackgroundColor"]!)
        self.selectedBackgroundColor = Color(theme[uicolor: "listSelectedBackgroundColor"]!)
        self.showThreadTags = showsThreadTags
        self.isUnread = !message.seen
        self.isReplied = message.replied
        self.isForwarded = message.forwarded
        
        // Sender
        self.sender = message.fromUsername ?? ""
        self.senderFont = UIFont.preferredFontForTextStyle(
            .body,
            fontName: theme["listFontName"],
            sizeAdjustment: theme[double: "messageListSenderFontSizeAdjustment"] ?? 0,
            weight: .semibold
        )
        self.senderColor = Color(theme[uicolor: "listSecondaryTextColor"]!)
        
        // Subject
        self.subject = message.subject ?? ""
        self.subjectFont = UIFont.preferredFontForTextStyle(
            .body,
            fontName: theme["listFontName"],
            sizeAdjustment: theme[double: "messageListSubjectFontSizeAdjustment"] ?? 0,
            weight: .regular
        )
        self.subjectColor = Color(theme[uicolor: "listTextColor"]!)
        
        // Sent date
        self.sentDate = Self.formattedDate(message.sentDate)
        self.sentDateFont = UIFont.preferredFontForTextStyle(
            .body,
            fontName: theme["listFontName"],
            sizeAdjustment: theme[double: "messageListSentDateFontSizeAdjustment"] ?? 0,
            weight: .semibold
        )
        self.sentDateColor = Color(theme[uicolor: "listSecondaryTextColor"]!)
        
        // Tag image
        if showsThreadTags {
            self.tagImageName = message.threadTag?.imageName
            self.tagImagePlaceholder = .privateMessage
        } else {
            self.tagImageName = nil
            self.tagImagePlaceholder = nil
        }
        
        // Overlay image for status (replied/forwarded/unread)
        if message.replied {
            self.overlayImage = UIImage(named: "pmreplied")
        } else if message.forwarded {
            self.overlayImage = UIImage(named: "pmforwarded")
        } else if !message.seen {
            self.overlayImage = UIImage(named: "newpm")
        } else {
            self.overlayImage = nil
        }
    }
    
    private static func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let calendar = Calendar.current
        let units: Set<Calendar.Component> = [.day, .month, .year]
        let sent = calendar.dateComponents(units, from: date)
        let today = calendar.dateComponents(units, from: Date())
        let formatter = sent == today ? sentTimeFormatter : sentDateFormatter
        return formatter.string(from: date)
    }
    
    static let empty: MessageRowViewModel = MessageRowViewModel(
        id: "",
        backgroundColor: .clear,
        selectedBackgroundColor: .clear,
        sender: "",
        senderColor: .primary,
        senderFont: UIFont.systemFont(ofSize: 17),
        sentDate: "",
        sentDateColor: .secondary,
        sentDateFont: UIFont.systemFont(ofSize: 17),
        subject: "",
        subjectColor: .primary,
        subjectFont: UIFont.systemFont(ofSize: 17),
        tagImageName: nil,
        tagImagePlaceholder: nil,
        overlayImage: nil,
        showThreadTags: true,
        isUnread: false,
        isReplied: false,
        isForwarded: false
    )
    
    private init(
        id: String,
        backgroundColor: Color,
        selectedBackgroundColor: Color,
        sender: String,
        senderColor: Color,
        senderFont: UIFont,
        sentDate: String,
        sentDateColor: Color,
        sentDateFont: UIFont,
        subject: String,
        subjectColor: Color,
        subjectFont: UIFont,
        tagImageName: String?,
        tagImagePlaceholder: ThreadTagLoader.Placeholder?,
        overlayImage: UIImage?,
        showThreadTags: Bool,
        isUnread: Bool,
        isReplied: Bool,
        isForwarded: Bool
    ) {
        self.id = id
        self.backgroundColor = backgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.sender = sender
        self.senderColor = senderColor
        self.senderFont = senderFont
        self.sentDate = sentDate
        self.sentDateColor = sentDateColor
        self.sentDateFont = sentDateFont
        self.subject = subject
        self.subjectColor = subjectColor
        self.subjectFont = subjectFont
        self.tagImageName = tagImageName
        self.tagImagePlaceholder = tagImagePlaceholder
        self.overlayImage = overlayImage
        self.showThreadTags = showThreadTags
        self.isUnread = isUnread
        self.isReplied = isReplied
        self.isForwarded = isForwarded
    }
}

private let sentDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMM YY"
    return formatter
}()

private let sentTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()