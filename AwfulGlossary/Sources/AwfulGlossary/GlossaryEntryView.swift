//  GlossaryEntryView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import SwiftUI

/// A single member-contributed SAclopedia entry: a byline (author + date) and the rendered body.
struct GlossaryEntryView: View {
    @Environment(\.theme) var theme
    let entry: GlossaryTopicScrapeResult.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(entry.authorUsername)
                    .fontWeight(.semibold)
                    .foregroundColor(theme[color: "listTextColor"])
                if !entry.postedDateText.isEmpty {
                    Text("·")
                        .foregroundColor(theme[color: "listSecondaryTextColor"])
                    Text(entry.postedDateText)
                        .foregroundColor(theme[color: "listSecondaryTextColor"])
                }
            }
            .font(.footnote)

            Text(renderedBody)
                .font(.body)
                .tint(theme[color: "tintColor"])
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(theme[color: "sheetBackgroundColor"]!)
        .cornerRadius(12)
    }

    private var renderedBody: AttributedString {
        var string = GlossaryHTMLRenderer.attributedString(
            fromHTML: entry.bodyHTML,
            baseURL: ForumsClient.shared.baseURL
        )
        string.foregroundColor = theme[color: "listTextColor"]
        if let tint = theme[color: "tintColor"] {
            for run in string.runs {
                let isLink = run.link != nil
                let isBold = run.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false
                if isLink || isBold {
                    string[run.range].foregroundColor = tint
                }
            }
        }
        return string
    }
}

/// Full-width status view used for loading errors and empty results, with an optional retry.
struct GlossaryMessageView: View {
    @Environment(\.theme) var theme
    let text: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
            if let retry {
                Button(action: retry) { Text("Try Again", bundle: .module) }
                    .tint(theme[color: "tintColor"])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 60)
    }
}
