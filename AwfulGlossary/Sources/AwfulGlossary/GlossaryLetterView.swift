//  GlossaryLetterView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulExtensions
import AwfulTheming
import SwiftUI

/// Lists the SAclopedia topics beginning with a given letter; each row pushes the topic.
struct GlossaryLetterView: View {
    @Environment(\.theme) var theme
    @Environment(\.glossaryExit) var glossaryExit
    @StateObject private var viewModel: GlossaryLetterViewModel
    private let letter: Character

    init(letter: Character) {
        self.letter = letter
        _viewModel = StateObject(wrappedValue: GlossaryLetterViewModel(letter: letter))
    }

    var body: some View {
        ScrollView {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .tint(theme[color: "tintColor"])
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)

            case .failed(let message):
                GlossaryMessageView(text: message) {
                    Task { await viewModel.load() }
                }

            case .loaded(let index):
                if index.topics.isEmpty {
                    GlossaryMessageView(text: "No topics start with “\(letter)”.")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(index.topics) { topic in
                            NavigationLink {
                                GlossaryTopicView(source: .topic(id: topic.topicID))
                            } label: {
                                GlossaryTopicRow(title: topic.title)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(theme[color: "backgroundColor"]!)
        .backport.fontDesign(theme.roundedFonts ? .rounded : nil)
        .navigationTitle(String(letter))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarHidingSharedBackgroundWhenGlassDisabled {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: glossaryExit) { Text("Exit", bundle: .module) }
                    .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
            }
        }
        .task {
            if case .loading = viewModel.state {
                await viewModel.load()
            }
        }
    }
}

/// A tappable topic row: title plus a disclosure chevron.
private struct GlossaryTopicRow: View {
    @Environment(\.theme) var theme
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(theme[color: "listTextColor"])
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme[color: "sheetBackgroundColor"]!)
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}

@MainActor
final class GlossaryLetterViewModel: ObservableObject {

    enum State {
        case loading
        case loaded(GlossaryIndexScrapeResult)
        case failed(String)
    }

    @Published var state: State = .loading
    let letter: Character

    init(letter: Character) {
        self.letter = letter
    }

    func load() async {
        state = .loading
        do {
            let result = try await ForumsClient.shared.glossaryTopics(letter: letter)
            state = .loaded(result)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
