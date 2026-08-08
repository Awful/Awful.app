//  PollViewerView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import Smilies
import SwiftUI
import UIKit

/// Shows a thread's poll, and votes on it. Present it via ``PollViewerHostingController``.
///
/// The forums show you either a ballot or the results, never both, so "let me see how it's going
/// without voting" means a second trip to `poll.php`. The segmented control hides that.
struct PollViewerView: View {
    @StateObject private var model: PollViewerModel
    @SwiftUI.Environment(\.theme) private var theme

    /// Closes the sheet (supplied by the hosting controller).
    let onDone: () -> Void
    /// Hands back the poll after a vote lands, so the thread can hold onto the fresher copy.
    let onVoted: (ThreadPoll) -> Void

    init(
        poll: ThreadPoll,
        onDone: @escaping () -> Void,
        onVoted: @escaping (ThreadPoll) -> Void
    ) {
        _model = StateObject(wrappedValue: PollViewerModel(poll: poll))
        self.onDone = onDone
        self.onVoted = onVoted
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme[color: "backgroundColor"]!.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Poll", bundle: .module)
                        .font(.headline)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Done", bundle: .module), action: onDone)
                        .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                }
            }
            .background(NavigationConfigurator(theme: theme))
        }
        .navigationViewStyle(.stack)
        .liquidGlassNavigationTint(theme[color: "tintColor"])
        .applyFontDesign(if: theme.roundedFonts)
    }

    private var content: some View {
        List {
            questionSection
            // A "Vote" tab you can't use is worse than no tab at all, so the picker only shows up
            // when there's actually a choice to make.
            if model.canVote {
                tabSection
            }
            if model.tab == .vote, model.canVote {
                voteSection
            } else {
                resultsSection
            }
        }
        .listStyle(.insetGrouped)
        .modifier(HiddenScrollBackground())
    }

    // MARK: Question

    private var questionSection: some View {
        Section {
            Text(model.poll.question)
                .font(.headline)
                .foregroundColor(theme[color: "listTextColor"])
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    // MARK: Vote / Results picker

    private var tabSection: some View {
        Section {
            // The `label:`-as-a-value initializer, not the trailing-closure one, which is iOS 16+.
            // The segmented style doesn't render the label; it's here for VoiceOver.
            Picker(selection: $model.tab, label: Text("Poll", bundle: .module)) {
                Text("Vote", bundle: .module).tag(PollViewerModel.Tab.vote)
                Text("Results", bundle: .module).tag(PollViewerModel.Tab.results)
            }
            .pickerStyle(.segmented)
            .tint(theme[color: "tintColor"])
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    // MARK: Vote

    private var voteSection: some View {
        Section {
            ForEach(model.poll.options) { option in
                Button {
                    model.toggle(option)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: model.selectionSymbol(for: option))
                            .foregroundColor(theme[color: "tintColor"])
                        PollOptionLabel(option: option, color: theme[color: "listTextColor"])
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await model.vote(onVoted: onVoted) }
            } label: {
                HStack {
                    Spacer()
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Vote", bundle: .module)
                            .foregroundColor(theme[color: "tintColor"])
                    }
                    Spacer()
                }
            }
            .disabled(model.selection.isEmpty || model.isSubmitting)

            if let error = model.voteError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        } footer: {
            Text(model.poll.ballot?.allowsMultipleChoice == true
                 ? String(localized: "Pick as many as you like.", bundle: .module)
                 : String(localized: "Pick one.", bundle: .module))
                .font(.caption)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    // MARK: Results

    @ViewBuilder
    private var resultsSection: some View {
        switch model.resultsState {
        case .available(let poll):
            resultsList(poll)

        case .loading:
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                // Only fetch once the user actually asks to see the results — this is the "look
                // without voting" trip, and it shouldn't happen behind their back.
                .task { await model.loadResults() }
            }
            .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])

        case .unavailable:
            Section {
                Text("Results aren't available for this poll.", bundle: .module)
                    .foregroundColor(theme[color: "listSecondaryTextColor"])
            }
            .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])

        case .failed(let message):
            Section {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.red)
                Button {
                    Task { await model.loadResults(force: true) }
                } label: {
                    Text("Try Again", bundle: .module)
                        .foregroundColor(theme[color: "tintColor"])
                }
            }
            .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
        }
    }

    private func resultsList(_ poll: ThreadPoll) -> some View {
        // Dim the also-rans a little so the leader reads at a glance.
        let mostVotes = poll.options.compactMap(\.voteCount).max()
        return Section {
            ForEach(poll.options) { option in
                resultRow(option, isLeading: option.voteCount != nil && option.voteCount == mostVotes)
            }
        } footer: {
            if let total = poll.totalVotes {
                Text("\(total) votes so far", bundle: .module)
                    .font(.caption)
                    .foregroundColor(theme[color: "listSecondaryTextColor"])
            }
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    private func resultRow(_ option: ThreadPoll.Option, isLeading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                PollOptionLabel(option: option, color: theme[color: "listTextColor"])
                Spacer(minLength: 12)
                Text(option.percentage.map { String(format: "%.0f%%", $0) } ?? "")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(theme[color: "listSecondaryTextColor"])
                Text(option.voteCount.map { "(\($0))" } ?? "")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(theme[color: "listSecondaryTextColor"])
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme[color: "listSecondaryTextColor"]?.opacity(0.2) ?? Color.gray.opacity(0.2))
                    Capsule()
                        .fill(theme[color: "tintColor"] ?? Color.accentColor)
                        .frame(width: proxy.size.width * CGFloat((option.percentage ?? 0) / 100))
                }
            }
            .frame(height: 6)
            .opacity(isLeading ? 1 : 0.75)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Option labels

/// An option's label, with smilies drawn as smilies rather than printed as `":q:"`.
///
/// Poll options are short by nature, so a plain `HStack` of runs is enough; there's no call for a
/// wrapping flow layout here.
private struct PollOptionLabel: View {
    let option: ThreadPoll.Option
    let color: Color?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(option.segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let string):
                    Text(string)
                        .foregroundColor(color)
                case .image(let url, let alt):
                    PollSmilieView(url: url, alt: alt, color: color)
                }
            }
        }
        // The runs are one label as far as VoiceOver is concerned, and `text` already spells the
        // smilies out.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.text)
    }
}

/// A smilie in a poll option.
///
/// Looks the smilie up in the bundled smilie store by its text form, so the common ones draw
/// instantly, animate, and work offline. Anything not in there — a rare or newly added smilie —
/// falls back to the image the forums pointed at, and failing that to the `":q:"` text, which is
/// what a goon would read anyway.
private struct PollSmilieView: View {
    let url: URL?
    let alt: String
    let color: Color?

    @AppStorage(Settings.loadImages) private var loadImages
    @State private var stored: (data: Data, size: CGSize)?
    @State private var didLookUp = false

    /// Roughly a line of body text; SA smilies are small, and this keeps a tall one from bloating
    /// the row.
    private static let maximumHeight: CGFloat = 22

    var body: some View {
        Group {
            if !loadImages {
                fallback
            } else if let stored {
                AnimatedImageView(data: stored.data, imageID: alt)
                    .frame(width: size(for: stored.size).width, height: size(for: stored.size).height)
            } else if didLookUp, let url {
                AsyncImage(url: url) { image in
                    image.resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                } placeholder: {
                    fallback
                }
                .frame(maxHeight: Self.maximumHeight)
            } else {
                fallback
            }
        }
        .onAppear(perform: lookUp)
    }

    private var fallback: some View {
        Text(alt).foregroundColor(color)
    }

    /// Scales the smilie down to fit `maximumHeight`, never up — SA smilies are pixel art and look
    /// wrong enlarged.
    private func size(for natural: CGSize) -> CGSize {
        guard natural.height > 0 else { return CGSize(width: Self.maximumHeight, height: Self.maximumHeight) }
        let scale = min(1, Self.maximumHeight / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }

    private func lookUp() {
        guard !didLookUp else { return }
        didLookUp = true
        guard loadImages,
              let smilie = SmilieDataStore.shared.fetchSmilie(text: alt),
              let data = smilie.imageData,
              let image = UIImage(data: data)
        else { return }
        stored = (data, image.size)
    }
}

/// Wraps `.scrollContentBackground(.hidden)` (iOS 16+) so the themed background shows through the
/// list; a no-op on iOS 15.
private struct HiddenScrollBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

// MARK: - Model

@MainActor
final class PollViewerModel: ObservableObject {

    enum Tab: Hashable {
        case vote, results
    }

    enum ResultsState {
        case available(ThreadPoll)
        case loading
        /// No results to be had: this poll came without one, and we've no poll ID to go asking with.
        case unavailable
        case failed(String)
    }

    @Published private(set) var poll: ThreadPoll
    @Published var tab: Tab
    @Published private(set) var selection: Set<Int> = []
    @Published private(set) var isSubmitting = false
    @Published private(set) var voteError: String?
    @Published private(set) var resultsState: ResultsState
    /// Guards against the spinner row's `.task` re-entering `loadResults` while it's already running.
    private var isLoadingResults = false

    init(poll: ThreadPoll) {
        self.poll = poll
        self.tab = poll.canVote ? .vote : .results
        self.resultsState = Self.resultsState(for: poll)
    }

    var canVote: Bool { poll.canVote && !poll.options.isEmpty }

    private static func resultsState(for poll: ThreadPoll) -> ResultsState {
        if poll.hasResults {
            return .available(poll)
        } else if poll.pollID != nil {
            return .loading
        } else {
            // Nothing to show and no way to fetch it. Not an error, just a dead end.
            return .unavailable
        }
    }

    func selectionSymbol(for option: ThreadPoll.Option) -> String {
        let picked = selection.contains(option.id)
        if poll.ballot?.allowsMultipleChoice == true {
            return picked ? "checkmark.square.fill" : "square"
        } else {
            return picked ? "largecircle.fill.circle" : "circle"
        }
    }

    func toggle(_ option: ThreadPoll.Option) {
        voteError = nil
        if poll.ballot?.allowsMultipleChoice == true {
            if selection.contains(option.id) {
                selection.remove(option.id)
            } else {
                selection.insert(option.id)
            }
        } else {
            selection = [option.id]
        }
    }

    func loadResults(force: Bool = false) async {
        if case .available = resultsState, !force { return }
        // Moving to `.loading` puts the spinner row on screen, whose `.task` calls straight back in
        // here. Without this we'd fire two GETs for every retry.
        guard !isLoadingResults else { return }
        guard let pollID = poll.pollID else {
            resultsState = .unavailable
            return
        }
        isLoadingResults = true
        resultsState = .loading
        defer { isLoadingResults = false }
        do {
            let fetched = try await ForumsClient.shared.pollResults(pollID: pollID)
            resultsState = .available(fetched)
        } catch {
            resultsState = .failed(error.localizedDescription)
        }
    }

    func vote(onVoted: (ThreadPoll) -> Void) async {
        guard !isSubmitting, !selection.isEmpty else { return }
        isSubmitting = true
        voteError = nil
        defer { isSubmitting = false }

        do {
            let voted = try await ForumsClient.shared.votePoll(poll, choosing: Array(selection).sorted())
            poll = voted
            selection = []
            resultsState = Self.resultsState(for: voted)
            // Stay put rather than dismissing: whoever just voted wants to see how it landed. The
            // picker disappears on its own now that there's no ballot.
            tab = .results
            onVoted(voted)
            if case .loading = resultsState {
                await loadResults()
            }
        } catch {
            voteError = error.localizedDescription
        }
    }
}

// MARK: - Hosting controller

final class PollViewerHostingController: UIHostingController<AnyView> {

    /// - Parameter theme: The posts page's theme, which is forum-specific. Note that we inject it
    ///   directly rather than using `.themed()`, which would resolve the *default* theme.
    init(
        poll: ThreadPoll,
        theme: Theme,
        onVoted: @escaping (ThreadPoll) -> Void
    ) {
        super.init(rootView: AnyView(EmptyView()))
        rootView = AnyView(
            PollViewerView(
                poll: poll,
                onDone: { [weak self] in self?.dismiss(animated: true) },
                onVoted: onVoted
            )
            .environment(\.theme, theme)
        )
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
