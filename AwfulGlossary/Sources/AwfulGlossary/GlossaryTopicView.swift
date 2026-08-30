//  GlossaryTopicView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulExtensions
import AwfulTheming
import SwiftUI

/// Shows one SAclopedia topic — its title and every member-contributed entry. Built for either a
/// random topic (with a shuffle button to load another) or a specific topic by ID.
struct GlossaryTopicView: View {
    @Environment(\.theme) var theme
    @Environment(\.glossaryExit) var glossaryExit
    @StateObject private var viewModel: GlossaryTopicViewModel

    init(source: GlossaryTopicViewModel.Source) {
        _viewModel = StateObject(wrappedValue: GlossaryTopicViewModel(source: source))
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

            case .loaded(let topic):
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text(topic.title)
                        .font(.title.bold())
                        .foregroundColor(theme[color: "listTextColor"])
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if topic.entries.isEmpty {
                        Text("This topic has no entries yet.", bundle: .module)
                            .foregroundColor(theme[color: "listSecondaryTextColor"])
                    } else {
                        ForEach(topic.entries) { entry in
                            GlossaryEntryView(entry: entry)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .background(theme[color: "backgroundColor"]!)
        .backport.fontDesign(theme.roundedFonts ? .rounded : nil)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarHidingSharedBackgroundWhenGlassDisabled {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: glossaryExit) { Text("Exit", bundle: .module) }
                    .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
            }
            // The `if` lives inside the ToolbarItem's ViewBuilder (iOS 15-safe); a conditional
            // *ToolbarContent* would require iOS 16.
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.source.isRandom {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                    .accessibilityLabel(Text("Random Topic", bundle: .module))
                }
            }
        }
        .task {
            if case .loading = viewModel.state {
                await viewModel.load()
            }
        }
    }
}

@MainActor
final class GlossaryTopicViewModel: ObservableObject {

    enum Source {
        case random
        case topic(id: String)

        var isRandom: Bool {
            if case .random = self { return true }
            return false
        }
    }

    enum State {
        case loading
        case loaded(GlossaryTopicScrapeResult)
        case failed(String)
    }

    @Published var state: State = .loading
    let source: Source

    init(source: Source) {
        self.source = source
    }

    func load() async {
        state = .loading
        do {
            let result: GlossaryTopicScrapeResult
            switch source {
            case .random:
                result = try await ForumsClient.shared.randomGlossaryTopic()
            case .topic(let id):
                result = try await ForumsClient.shared.glossaryTopic(id: id)
            }
            state = .loaded(result)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
