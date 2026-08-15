//  PollEditorView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulExtensions
import AwfulTheming
import SwiftUI
import UIKit

/// Composes the poll that gets attached to a new thread. Present it via ``PollEditorHostingController``.
///
/// The forums make you post the thread first and add the poll on a second page; we hide that by
/// collecting everything here, up front, and doing the second step automatically after the thread
/// goes up.
struct PollEditorView: View {
    @StateObject private var model: PollEditorModel
    @SwiftUI.Environment(\.theme) private var theme
    @FocusState private var focusedField: Field?

    /// Dismisses without saving (supplied by the hosting controller).
    let onCancel: () -> Void
    /// Hands back the poll, or nil if the user removed it.
    let onSave: (PollSubmission?) -> Void

    private enum Field: Hashable {
        case question
        case option(UUID)
    }

    init(
        poll: PollSubmission?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (PollSubmission?) -> Void
    ) {
        _model = StateObject(wrappedValue: PollEditorModel(poll: poll))
        self.hadExistingPoll = poll != nil
        self.onCancel = onCancel
        self.onSave = onSave
    }

    private let hadExistingPoll: Bool

    var body: some View {
        NavigationView {
            ZStack {
                theme[color: "backgroundColor"]!.ignoresSafeArea()
                form
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Poll", bundle: .module)
                        .font(.headline)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "Cancel", bundle: .module), action: onCancel)
                        .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "Save", bundle: .module)) { onSave(model.poll.normalized) }
                        .disabled(!model.poll.isValid)
                        .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                }
            }
            .background(NavigationConfigurator(theme: theme))
        }
        .navigationViewStyle(.stack)
        .liquidGlassNavigationTint(theme[color: "tintColor"])
        .applyFontDesign(if: theme.roundedFonts)
    }

    private var form: some View {
        List {
            questionSection
            optionsSection
            settingsSection
            if hadExistingPoll {
                removeSection
            }
        }
        .listStyle(.insetGrouped)
        .modifier(HiddenScrollBackground())
    }

    // MARK: Question

    private var questionSection: some View {
        Section {
            TextField(String(localized: "What are you asking?", bundle: .module), text: $model.question)
                .focused($focusedField, equals: .question)
                .foregroundColor(theme[color: "listTextColor"])
                .submitLabel(.next)
                .onSubmit { focusedField = model.options.first.map { .option($0.id) } }
        } header: {
            sectionHeader(String(localized: "Question", bundle: .module))
        } footer: {
            Text("\(model.question.count) of \(PollSubmission.maximumQuestionLength) characters", bundle: .module)
                .font(.caption)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    // MARK: Options

    private var optionsSection: some View {
        Section {
            // ForEach over the identified options, not their indices, so reordering doesn't scramble
            // which text field is which.
            ForEach($model.options) { $option in
                TextField(String(localized: "Option", bundle: .module), text: $option.text)
                    .focused($focusedField, equals: .option(option.id))
                    .foregroundColor(theme[color: "listTextColor"])
            }
            .onDelete { model.removeOptions(at: $0) }
            .onMove { model.moveOptions(from: $0, to: $1) }

            Button {
                if let added = model.addOption() {
                    focusedField = .option(added)
                }
            } label: {
                Label(String(localized: "Add option", bundle: .module), systemImage: "plus.circle.fill")
                    .foregroundColor(theme[color: "tintColor"])
            }
            .disabled(!model.canAddOption)
        } header: {
            HStack {
                sectionHeader(String(localized: "Options", bundle: .module))
                Spacer()
                // Reordering needs edit mode; deleting works by swiping either way.
                EditButton()
                    .foregroundColor(theme[color: "tintColor"])
                    .textCase(nil)
            }
        } footer: {
            Text("Keep them short and to the point. Between \(PollSubmission.optionCountRange.lowerBound) and \(PollSubmission.optionCountRange.upperBound) options; blank ones are dropped.", bundle: .module)
                .font(.caption)
                .foregroundColor(theme[color: "listSecondaryTextColor"])
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    // MARK: Settings

    private var settingsSection: some View {
        Section {
            Toggle(isOn: $model.allowsMultipleChoice) {
                Text("Allow multiple choice", bundle: .module)
                    .foregroundColor(theme[color: "listTextColor"])
            }
            .tint(theme[color: "tintColor"])

            Picker(selection: $model.timeoutDays) {
                ForEach(PollEditorModel.timeoutChoices, id: \.self) { days in
                    Text(PollEditorModel.timeoutLabel(days)).tag(days)
                }
            } label: {
                Text("Poll runs for", bundle: .module)
                    .foregroundColor(theme[color: "listTextColor"])
            }
            .tint(theme[color: "listSecondaryTextColor"])
        } header: {
            sectionHeader(String(localized: "Settings", bundle: .module))
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    private var removeSection: some View {
        Section {
            Button(role: .destructive) {
                onSave(nil)
            } label: {
                Text("Remove poll", bundle: .module)
            }
        }
        .listRowBackground(theme[color: "sheetBackgroundColor"] ?? theme[color: "listBackgroundColor"])
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(theme[color: "listSecondaryTextColor"])
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
final class PollEditorModel: ObservableObject {

    /// Options need stable identities so `ForEach` survives reordering and deletion.
    struct Option: Identifiable, Equatable {
        let id = UUID()
        var text: String
    }

    @Published var question: String = "" {
        didSet {
            // The forums' field is maxlength=85 and silently truncates; do it visibly instead.
            if question.count > PollSubmission.maximumQuestionLength {
                question = String(question.prefix(PollSubmission.maximumQuestionLength))
            }
        }
    }
    @Published var options: [Option]
    @Published var allowsMultipleChoice: Bool
    @Published var timeoutDays: Int

    static let timeoutChoices = [0, 1, 3, 7, 14, 30, 60, 90]

    init(poll: PollSubmission?) {
        let poll = poll ?? PollSubmission()
        question = poll.question
        // Always show at least the minimum number of blanks so there's something to type into.
        let texts = poll.options.isEmpty
            ? Array(repeating: "", count: PollSubmission.optionCountRange.lowerBound)
            : poll.options
        options = texts.map { Option(text: $0) }
        allowsMultipleChoice = poll.allowsMultipleChoice
        timeoutDays = poll.timeoutDays
    }

    var poll: PollSubmission {
        PollSubmission(
            question: question,
            options: options.map(\.text),
            allowsMultipleChoice: allowsMultipleChoice,
            timeoutDays: timeoutDays
        )
    }

    var canAddOption: Bool {
        options.count < PollSubmission.optionCountRange.upperBound
    }

    /// - Returns: The new option's id, so the caller can focus it, or nil if we're at the cap.
    @discardableResult
    func addOption() -> UUID? {
        guard canAddOption else { return nil }
        let option = Option(text: "")
        options.append(option)
        return option.id
    }

    func removeOptions(at offsets: IndexSet) {
        options.remove(atOffsets: offsets)
        // Keep enough rows around to build a valid poll.
        while options.count < PollSubmission.optionCountRange.lowerBound {
            options.append(Option(text: ""))
        }
    }

    func moveOptions(from source: IndexSet, to destination: Int) {
        options.move(fromOffsets: source, toOffset: destination)
    }

    static func timeoutLabel(_ days: Int) -> String {
        days == 0
            ? String(localized: "Forever", bundle: .module)
            : String(localized: "\(days) days", bundle: .module)
    }
}

// MARK: - Hosting controller

public final class PollEditorHostingController: UIHostingController<AnyView> {

    /// - Parameter theme: The compose screen's theme, which is forum-specific. Note that we inject
    ///   it directly rather than using `.themed()`, which would resolve the *default* theme.
    public init(
        poll: PollSubmission?,
        theme: Theme,
        onCancel: @escaping () -> Void,
        onSave: @escaping (PollSubmission?) -> Void
    ) {
        super.init(rootView: AnyView(EmptyView()))
        rootView = AnyView(
            PollEditorView(poll: poll, onCancel: onCancel, onSave: onSave)
                .environment(\.theme, theme)
        )
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    @MainActor public required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
