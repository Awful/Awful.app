//  CustomThemeEditorView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import UniformTypeIdentifiers

/// Editor for the user-defined custom theme, allowing modification of native UI properties and WebView CSS.
public struct CustomThemeEditorView: View {
    @ObservedObject private var manager = CustomThemeManager.shared

    @State private var showingThemePicker = false
    @State private var showingResetConfirmation = false
    @State private var showingImportPicker = false
    @State private var importError: String?
    @State private var showingImportError = false

    private static let exportTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    public init() {}

    public var body: some View {
        Form {
            startingPointSection
            stylesheetSection

            ForEach(themePropertiesByCategory, id: \.0) { category, properties in
                Section(header: Text(category.rawValue)) {
                    ForEach(properties, id: \.key) { property in
                        propertyRow(for: property)
                    }
                }
            }
        }
        .navigationTitle("Custom Theme")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button("Export Theme") {
                        exportTheme()
                    }
                    Button("Import Theme") {
                        showingImportPicker = true
                    }
                    Divider()
                    Button("Reset All to Defaults", role: .destructive) {
                        showingResetConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Reset Custom Theme?", isPresented: $showingResetConfirmation) {
            Button("Reset All to Defaults", role: .destructive) {
                manager.resetToDefaults()
            }
        } message: {
            Text("This will remove all your customizations and revert to the default theme values.")
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemeStartingPointPicker { theme in
                manager.copyFromTheme(theme)
                showingThemePicker = false
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPickerView { url, data in
                do {
                    switch url.pathExtension.lowercased() {
                    case "css":
                        try manager.importCSS(data)
                    default:
                        try manager.importFromJSON(data)
                    }
                } catch {
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK") {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    // MARK: - Sections

    private var startingPointSection: some View {
        Section(header: Text("Starting Point")) {
            if let baseName = manager.baseThemeName {
                HStack {
                    Text("Based on")
                    Spacer()
                    Text(baseName)
                        .foregroundColor(.secondary)
                }
            }
            Button("Start from Existing Theme\u{2026}") {
                showingThemePicker = true
            }
        }
    }

    private var stylesheetSection: some View {
        Section(header: Text("WebView Stylesheet")) {
            NavigationLink("Edit Stylesheet") {
                CSSEditorView()
            }
            if manager.customCSS != nil {
                let lineCount = manager.customCSS?.components(separatedBy: "\n").count ?? 0
                Text("\(lineCount) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Using bundled default stylesheet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Property Rows

    @ViewBuilder
    private func propertyRow(for property: ThemeProperty) -> some View {
        let isOverridden = manager.overrides[property.key] != nil

        switch property.type {
        case .color:
            colorRow(for: property, isOverridden: isOverridden)
        case .boolean:
            booleanRow(for: property, isOverridden: isOverridden)
        case .stringEnum(let options):
            stringEnumRow(for: property, options: options, isOverridden: isOverridden)
        case .string:
            stringRow(for: property, isOverridden: isOverridden)
        case .number:
            numberRow(for: property, isOverridden: isOverridden)
        case .fontName:
            fontNameRow(for: property, isOverridden: isOverridden)
        }
    }

    private func colorRow(for property: ThemeProperty, isOverridden: Bool) -> some View {
        let currentHex = currentStringValue(for: property.key) ?? "#000000"
        let color = Color(hex: currentHex) ?? .black

        return HStack {
            overrideIndicator(isOverridden)
            Text(property.displayName)
            Spacer()
            Text(currentHex)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
            ColorPicker("", selection: Binding(
                get: { color },
                set: { newColor in
                    let hex = newColor.hexString
                    manager.setValue(hex, forKey: property.key)
                }
            ), supportsOpacity: true)
            .labelsHidden()
            .frame(width: 30)
        }
        .swipeActions(edge: .trailing) {
            if isOverridden {
                Button("Reset") {
                    manager.removeValue(forKey: property.key)
                }
            }
        }
    }

    private func booleanRow(for property: ThemeProperty, isOverridden: Bool) -> some View {
        let currentValue = currentBoolValue(for: property.key)

        return HStack {
            overrideIndicator(isOverridden)
            Toggle(property.displayName, isOn: Binding(
                get: { currentValue },
                set: { manager.setValue($0, forKey: property.key) }
            ))
        }
        .swipeActions(edge: .trailing) {
            if isOverridden {
                Button("Reset") {
                    manager.removeValue(forKey: property.key)
                }
            }
        }
    }

    private func stringEnumRow(for property: ThemeProperty, options: [String], isOverridden: Bool) -> some View {
        let currentValue = currentStringValue(for: property.key) ?? options.first ?? ""

        return HStack {
            overrideIndicator(isOverridden)
            Picker(property.displayName, selection: Binding(
                get: { currentValue },
                set: { manager.setValue($0, forKey: property.key) }
            )) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if isOverridden {
                Button("Reset") {
                    manager.removeValue(forKey: property.key)
                }
            }
        }
    }

    private func stringRow(for property: ThemeProperty, isOverridden: Bool) -> some View {
        let currentValue = currentStringValue(for: property.key) ?? ""

        return HStack {
            overrideIndicator(isOverridden)
            Text(property.displayName)
            Spacer()
            TextField("Value", text: Binding(
                get: { currentValue },
                set: { manager.setValue($0, forKey: property.key) }
            ))
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 150)
        }
        .swipeActions(edge: .trailing) {
            if isOverridden {
                Button("Reset") {
                    manager.removeValue(forKey: property.key)
                }
            }
        }
    }

    private func numberRow(for property: ThemeProperty, isOverridden: Bool) -> some View {
        let currentValue = currentNumberValue(for: property.key)

        return HStack {
            overrideIndicator(isOverridden)
            Text(property.displayName)
            Spacer()
            TextField("0", text: Binding(
                get: { "\(currentValue)" },
                set: {
                    if let num = Int($0) {
                        manager.setValue(num, forKey: property.key)
                    }
                }
            ))
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 80)
            Stepper("", value: Binding(
                get: { currentValue },
                set: { manager.setValue($0, forKey: property.key) }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing) {
            if isOverridden {
                Button("Reset") {
                    manager.removeValue(forKey: property.key)
                }
            }
        }
    }

    private func fontNameRow(for property: ThemeProperty, isOverridden: Bool) -> some View {
        let currentValue = currentStringValue(for: property.key) ?? ""
        let displayName = currentValue.isEmpty ? "System Default" : currentValue

        return HStack {
            overrideIndicator(isOverridden)
            NavigationLink {
                FontPickerView(
                    selectedFont: currentValue,
                    onSelect: { fontName in
                        if fontName.isEmpty {
                            manager.removeValue(forKey: property.key)
                        } else {
                            manager.setValue(fontName, forKey: property.key)
                        }
                    }
                )
                .navigationTitle(property.displayName)
            } label: {
                HStack {
                    Text(property.displayName)
                    Spacer()
                    Text(displayName)
                        .foregroundColor(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if isOverridden {
                Button("Reset") {
                    manager.removeValue(forKey: property.key)
                }
            }
        }
    }

    @ViewBuilder
    private func overrideIndicator(_ isOverridden: Bool) -> some View {
        Circle()
            .fill(isOverridden ? Color.accentColor : Color.clear)
            .frame(width: 6, height: 6)
    }

    // MARK: - Value Helpers

    /// Gets the current effective string value for a key (override or bundled default).
    private func currentStringValue(for key: String) -> String? {
        if let override = manager.overrides[key] {
            return override as? String
        }
        // Fall back to the bundled customDefault theme's dictionary value
        return Theme.theme(named: "customDefault")?[string: key]
    }

    private func currentBoolValue(for key: String) -> Bool {
        if let override = manager.overrides[key] as? Bool {
            return override
        }
        return Theme.theme(named: "customDefault")?[bool: key] ?? false
    }

    private func currentNumberValue(for key: String) -> Int {
        if let override = manager.overrides[key] {
            if let intVal = override as? Int { return intVal }
            if let doubleVal = override as? Double { return Int(doubleVal) }
            if let strVal = override as? String, let intVal = Int(strVal) { return intVal }
        }
        if let doubleVal = Theme.theme(named: "customDefault")?[double: key] {
            return Int(doubleVal)
        }
        return 0
    }

    // MARK: - Export

    private func exportTheme() {
        do {
            let data = try manager.exportJSON()
            let timestamp = Self.exportTimestampFormatter.string(from: Date())
            let tempDir = FileManager.default.temporaryDirectory
            let jsonURL = tempDir.appendingPathComponent("custom-theme-\(timestamp).json")
            try data.write(to: jsonURL)

            var items: [Any] = [jsonURL]

            // Export CSS as a separate file if customized
            if let css = manager.customCSS {
                let cssURL = tempDir.appendingPathComponent("custom-theme-\(timestamp).css")
                try css.data(using: .utf8)?.write(to: cssURL)
                items.append(cssURL)
            }

            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                var presenter = rootVC
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                activityVC.popoverPresentationController?.sourceView = presenter.view
                presenter.present(activityVC, animated: true)
            }
        } catch {
            importError = "Export failed: \(error.localizedDescription)"
            showingImportError = true
        }
    }
}

// MARK: - CSS Editor

struct CSSEditorView: View {
    @ObservedObject private var manager = CustomThemeManager.shared
    @State private var editingCSS: String = ""
    @State private var searchText: String = ""
    @State private var matchCount: Int = 0
    @State private var currentMatch: Int = 0
    @State private var showingSearch = false

    var body: some View {
        VStack(spacing: 0) {
            if showingSearch {
                searchBar
            }
            SearchableTextEditor(
                text: $editingCSS,
                searchText: $searchText,
                matchCount: $matchCount,
                currentMatch: $currentMatch
            )
        }
        .navigationTitle("Stylesheet")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingSearch.toggle()
                    if !showingSearch {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    manager.setCustomCSS(editingCSS.isEmpty ? nil : editingCSS)
                }
            }
        }
        .onAppear {
            editingCSS = manager.customCSS ?? manager.resolvedCSS() ?? ""
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Find", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(6)
            .background(Color(.systemGray5))
            .cornerRadius(8)

            if !searchText.isEmpty && matchCount > 0 {
                Text("\(currentMatch)/\(matchCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40)

                Button { currentMatch = currentMatch > 1 ? currentMatch - 1 : matchCount }
                    label: { Image(systemName: "chevron.up") }
                Button { currentMatch = currentMatch < matchCount ? currentMatch + 1 : 1 }
                    label: { Image(systemName: "chevron.down") }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
}

/// A UITextView wrapper with search-and-highlight support.
struct SearchableTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var searchText: String
    @Binding var matchCount: Int
    @Binding var currentMatch: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.delegate = context.coordinator
        textView.backgroundColor = .systemBackground
        textView.keyboardDismissMode = .interactive
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            textView.selectedRange = selectedRange
        }
        context.coordinator.highlightMatches(in: textView, searchText: searchText, scrollToMatch: currentMatch)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SearchableTextEditor
        private var matchRanges: [NSRange] = []

        init(_ parent: SearchableTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func highlightMatches(in textView: UITextView, searchText: String, scrollToMatch: Int) {
            let storage = textView.textStorage
            let fullRange = NSRange(location: 0, length: storage.length)

            // Clear previous highlights
            storage.removeAttribute(.backgroundColor, range: fullRange)

            guard !searchText.isEmpty else {
                matchRanges = []
                DispatchQueue.main.async {
                    self.parent.matchCount = 0
                    self.parent.currentMatch = 0
                }
                return
            }

            // Find all matches
            let text = storage.string as NSString
            var ranges: [NSRange] = []
            var searchRange = NSRange(location: 0, length: text.length)
            let needle = searchText.lowercased() as NSString

            while searchRange.location < text.length {
                let range = text.range(of: needle as String, options: .caseInsensitive, range: searchRange)
                guard range.location != NSNotFound else { break }
                ranges.append(range)
                searchRange.location = range.location + range.length
                searchRange.length = text.length - searchRange.location
            }

            matchRanges = ranges

            // Highlight all matches
            for range in ranges {
                storage.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: range)
            }

            // Highlight current match and scroll to it
            if !ranges.isEmpty {
                let idx = max(0, min(scrollToMatch - 1, ranges.count - 1))
                storage.addAttribute(.backgroundColor, value: UIColor.orange.withAlphaComponent(0.5), range: ranges[idx])

                // Scroll to current match
                if let start = textView.position(from: textView.beginningOfDocument, offset: ranges[idx].location),
                   let end = textView.position(from: start, offset: ranges[idx].length),
                   let textRange = textView.textRange(from: start, to: end) {
                    let rect = textView.firstRect(for: textRange)
                    textView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -60), animated: true)
                }
            }

            DispatchQueue.main.async {
                self.parent.matchCount = ranges.count
                if ranges.isEmpty {
                    self.parent.currentMatch = 0
                } else if self.parent.currentMatch == 0 || self.parent.currentMatch > ranges.count {
                    self.parent.currentMatch = 1
                }
            }
        }
    }
}

// MARK: - Font Picker

struct FontPickerView: View {
    let selectedFont: String
    let onSelect: (String) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var fontFamilies: [String] {
        let families = UIFont.familyNames.sorted()
        if searchText.isEmpty { return families }
        return families.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            Section {
                Button {
                    onSelect("")
                    dismiss()
                } label: {
                    HStack {
                        Text("System Default")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedFont.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }

            ForEach(fontFamilies, id: \.self) { family in
                Section(header: Text(family)) {
                    ForEach(UIFont.fontNames(forFamilyName: family).sorted(), id: \.self) { fontName in
                        Button {
                            onSelect(fontName)
                            dismiss()
                        } label: {
                            HStack {
                                Text(fontName)
                                    .font(.custom(fontName, size: 17))
                                    .foregroundColor(.primary)
                                Spacer()
                                if fontName == selectedFont {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search fonts")
    }
}

// MARK: - Theme Starting Point Picker

struct ThemeStartingPointPicker: View {
    let onSelect: (Theme) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmTheme: Theme?

    var body: some View {
        NavigationView {
            List(Theme.allThemes.filter { $0.name != "customDefault" }, id: \.name) { theme in
                Button {
                    confirmTheme = theme
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(theme.descriptiveColor))
                            .frame(width: 24, height: 24)
                        Text(theme.descriptiveName)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Start from Theme")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Replace Custom Theme?",
                isPresented: Binding(
                    get: { confirmTheme != nil },
                    set: { if !$0 { confirmTheme = nil } }
                )
            ) {
                if let theme = confirmTheme {
                    Button("Replace with \(theme.descriptiveName)", role: .destructive) {
                        onSelect(theme)
                    }
                }
            } message: {
                Text("This will replace all your current custom theme values with the selected theme's values.")
            }
        }
    }
}

// MARK: - Document Picker for Import

struct DocumentPickerView: UIViewControllerRepresentable {
    let onImport: (URL, Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.json, UTType(filenameExtension: "css") ?? UTType.plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.compactMap { $0 })
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: (URL, Data) -> Void

        init(onImport: @escaping (URL, Data) -> Void) {
            self.onImport = onImport
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    onImport(url, data)
                }
            }
        }
    }
}

// MARK: - Color Helpers

extension Color {
    /// Creates a Color from a CSS hex string (e.g., "#ff0000", "#f00", "#ff000080").
    init?(hex: String) {
        let hexString = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let uiColor = UIColor(cssHex: hexString) else { return nil }
        self.init(uiColor)
    }

    /// Returns a hex string representation of this color.
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        if a < 1.0 {
            return String(format: "#%02x%02x%02x%02x",
                          Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        }
        return String(format: "#%02x%02x%02x",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

private extension UIColor {
    convenience init?(cssHex hexString: String) {
        let scanner = Scanner(string: hexString)
        guard let hex = scanner.scanUInt64(representation: .hexadecimal) else { return nil }
        let length = hexString.count
        switch length {
        case 3:
            self.init(
                red: CGFloat((hex & 0xF00) >> 8) / 15,
                green: CGFloat((hex & 0x0F0) >> 4) / 15,
                blue: CGFloat((hex & 0x00F) >> 0) / 15,
                alpha: 1)
        case 4:
            self.init(
                red: CGFloat((hex & 0xF000) >> 12) / 15,
                green: CGFloat((hex & 0x0F00) >> 8) / 15,
                blue: CGFloat((hex & 0x00F0) >> 4) / 15,
                alpha: CGFloat((hex & 0x000F) >> 0) / 15)
        case 6:
            self.init(
                red: CGFloat((hex & 0xFF0000) >> 16) / 255,
                green: CGFloat((hex & 0x00FF00) >> 8) / 255,
                blue: CGFloat((hex & 0x0000FF) >> 0) / 255,
                alpha: 1)
        case 8:
            self.init(
                red: CGFloat((hex & 0xFF000000) >> 24) / 255,
                green: CGFloat((hex & 0x00FF0000) >> 16) / 255,
                blue: CGFloat((hex & 0x0000FF00) >> 8) / 255,
                alpha: CGFloat((hex & 0x000000FF) >> 0) / 255)
        default:
            return nil
        }
    }
}
