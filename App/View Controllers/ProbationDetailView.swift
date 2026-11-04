//  ProbationDetailView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import SwiftUI
import UIKit

/// The full probation notice, with links to the user's Leper's Colony record and the forum rules.
struct ProbationDetailView: View {
    let notice: ProbationNoticeScrapeResult
    let showRapSheet: () -> Void
    let showRules: () -> Void

    @SwiftUI.Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image("title-probation")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityHidden(true)
                    Text(verbatim: notice.title.isEmpty ? notice.localizedSummary : notice.title)
                        .font(.headline)
                        .foregroundColor(theme[color: "sheetTitleColor"])
                }

                Text(verbatim: notice.message)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    Button(action: showRapSheet) {
                        Text(LocalizedString("probation.detail.rap-sheet"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    Button(action: showRules) {
                        Text(LocalizedString("probation.detail.rules"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.bordered)
                .tint(theme[color: "tintColor"])
            }
            .padding(20)
        }
        .foregroundColor(theme[color: "sheetTextColor"])
        .background(theme[color: "sheetBackgroundColor"]!.ignoresSafeArea())
    }
}

extension ProbationDetailView {
    private static let rulesURL = URL(string: "https://www.somethingawful.com/d/forum-rules/forum-rules.php")!

    /// Presents the stored probation notice as a sheet. Does nothing if the user isn't on probation.
    @MainActor
    static func present(from presenter: UIViewController) {
        guard let notice = ProbationNoticeStore.current else { return }

        weak var sheet: UIViewController?
        let view = ProbationDetailView(
            notice: notice,
            showRapSheet: {
                sheet?.dismiss(animated: true) {
                    guard let userID = UserDefaults.standard.value(for: Settings.userID) else { return }
                    AppDelegate.instance.open(route: .rapSheet(userID: userID))
                }
            },
            showRules: { [weak presenter] in
                sheet?.dismiss(animated: true) {
                    guard let presenter else { return }
                    AwfulBrowser.presentBrowserForURL(rulesURL, fromViewController: presenter)
                }
            }
        )
        let hostingController = UIHostingController(rootView: view.themed())
        sheet = hostingController
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
        }
        presenter.present(hostingController, animated: true)
    }
}
