//  ArchivesView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulExtensions
import AwfulTheming
import SwiftUI
import UIKit

/// The archives "time machine" sheet: pick a Month / Day / Year to lock every forum into a past
/// timeframe (or return to live forums). Present it via ``ArchivesHostingController``.
///
/// Year values come from the site's own form (with a static fallback if that fetch fails), and the
/// currently-engaged timeframe (if any) is pre-selected. A day is only meaningful with a month, so
/// the Day picker is disabled until a Month is chosen.
struct ArchivesView: View {
    @StateObject private var model = ArchivesViewModel()
    @SwiftUI.Environment(\.theme) private var theme

    /// Dismisses the sheet (supplied by the hosting controller).
    let onExit: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                theme[color: "backgroundColor"]!.ignoresSafeArea()
                if model.isLoading {
                    ProgressView()
                        .tint(theme[color: "tintColor"])
                } else {
                    form
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Archives", bundle: .module)
                        .font(.headline)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onExit) { Text("Cancel", bundle: .module) }
                        .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                }
            }
            .background(NavigationConfigurator(theme: theme))
        }
        .navigationViewStyle(.stack)
        .liquidGlassNavigationTint(theme[color: "tintColor"])
        .applyFontDesign(if: theme.roundedFonts)
        .task { await model.load() }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse the forums as they were on a past date. This locks every forum to the selected timeframe until you return to live.", bundle: .module)
                    .font(.footnote)
                    .foregroundColor(theme[color: "listSecondaryTextColor"])

                VStack(spacing: 0) {
                    pickerRow("Month") { monthPicker }
                    rowDivider
                    pickerRow("Day") { dayPicker }
                        .opacity(model.selectedMonth == nil ? 0.4 : 1)
                    rowDivider
                    pickerRow("Year") { yearPicker }
                }
                .background(theme[color: "sheetBackgroundColor"]!)
                .cornerRadius(12)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(theme[color: "unreadBadgeRedColor"])
                }

                Button {
                    Task { if await model.engage() { onExit() } }
                } label: {
                    buttonLabel(model.isEngaged ? "Update Archives View" : "View Archives",
                                background: theme[color: "tintColor"]!,
                                foreground: .white)
                }
                .disabled(model.isSubmitting)

                if model.isEngaged {
                    Button {
                        Task { if await model.disengage() { onExit() } }
                    } label: {
                        buttonLabel("Return to Live Forums",
                                    background: theme[color: "sheetBackgroundColor"]!,
                                    foreground: theme[color: "tintColor"]!)
                    }
                    .disabled(model.isSubmitting)
                }
            }
            .padding()
        }
    }

    // MARK: Pieces

    private func pickerRow<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title, bundle: .module)
                .foregroundColor(theme[color: "listTextColor"])
            Spacer()
            content()
        }
        .padding(.horizontal)
        .frame(minHeight: 48)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(theme[color: "listSeparatorColor"] ?? Color.gray.opacity(0.3))
            .frame(height: 0.5)
    }

    private func buttonLabel(_ title: LocalizedStringKey, background: Color, foreground: Color) -> some View {
        Text(title, bundle: .module)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(12)
    }

    private var monthPicker: some View {
        Picker("Month", selection: $model.selectedMonth) {
            Text("Any", bundle: .module).tag(Int?.none)
            ForEach(1...12, id: \.self) { month in
                Text(ArchivesViewModel.monthNames[month - 1]).tag(Int?.some(month))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
    }

    private var dayPicker: some View {
        Picker("Day", selection: $model.selectedDay) {
            Text("Any", bundle: .module).tag(Int?.none)
            ForEach(1...31, id: \.self) { day in
                Text(String(day)).tag(Int?.some(day))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
        .disabled(model.selectedMonth == nil)
    }

    private var yearPicker: some View {
        Picker("Year", selection: $model.selectedYear) {
            // `String(year)` avoids the number formatter's grouping separator (e.g. "2,015").
            ForEach(model.availableYears, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
    }
}

// MARK: - View model

@MainActor
final class ArchivesViewModel: ObservableObject {
    @Published var availableYears: [Int] = ArchivesViewModel.fallbackYears
    /// `nil` means "Any"; clearing the month clears the (now-meaningless) day.
    @Published var selectedMonth: Int? { didSet { if selectedMonth == nil { selectedDay = nil } } }
    @Published var selectedDay: Int?
    @Published var selectedYear: Int
    @Published var isLoading = true
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    static let monthNames = Calendar.current.monthSymbols

    /// Newest-first list used until (or unless) the site's real years load.
    static var fallbackYears: [Int] {
        let thisYear = Calendar.current.component(.year, from: Date())
        return Array(stride(from: max(thisYear, 2001), through: 2001, by: -1))
    }

    init() {
        selectedMonth = nil
        selectedDay = nil
        selectedYear = ArchivesViewModel.fallbackYears.first ?? 2015
    }

    var isEngaged: Bool { ForumsClient.shared.currentArchivesTimeframe != nil }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let scraped = try await ForumsClient.shared.fetchArchivesForm()
            availableYears = scraped.availableYears.isEmpty ? Self.fallbackYears : scraped.availableYears
            if let timeframe = scraped.selectedTimeframe {
                selectedMonth = timeframe.month
                selectedDay = timeframe.day
                selectedYear = timeframe.year
            } else if !availableYears.contains(selectedYear) {
                selectedYear = availableYears.first ?? selectedYear
            }
        } catch {
            availableYears = Self.fallbackYears
            if !availableYears.contains(selectedYear) {
                selectedYear = availableYears.first ?? selectedYear
            }
            errorMessage = String(localized: "Couldn't load archive years from the Forums; showing a default range.", bundle: .module)
        }
        isLoading = false
    }

    func engage() async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await ForumsClient.shared.setArchivesTimeframe(month: selectedMonth, day: selectedDay, year: selectedYear)
            return true
        } catch {
            errorMessage = String(localized: "Couldn't switch to archives: \(error.localizedDescription)", bundle: .module)
            return false
        }
    }

    func disengage() async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await ForumsClient.shared.removeArchivesTimeframe()
            return true
        } catch {
            errorMessage = String(localized: "Couldn't return to live forums: \(error.localizedDescription)", bundle: .module)
            return false
        }
    }
}

// MARK: - Hosting controller

/// Hosts ``ArchivesView`` as a themed medium sheet. Present modally from the Forums screen. Mirrors
/// the other modal SwiftUI sheets so the status-bar style stays consistent with the app theme.
public final class ArchivesHostingController: UIHostingController<AnyView> {

    public init() {
        super.init(rootView: AnyView(EmptyView()))
        rootView = AnyView(
            ArchivesView(onExit: { [weak self] in self?.dismiss(animated: true) })
                .themed()
        )
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            // On iPad the medium detent is too short to fit the whole form — the bottom
            // "Return to Live Forums" button gets cut off on iPad mini — so open at the large
            // detent there. iPhone keeps the medium default and can still drag up.
            if UIDevice.current.userInterfaceIdiom == .pad {
                sheet.selectedDetentIdentifier = .large
            }
        }
    }

    @MainActor public required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationCapturesStatusBarAppearance = true
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        let theme = Theme.defaultTheme()
        return (theme["statusBarBackground"] == "light") ? .darkContent : .lightContent
    }

    public override var childForStatusBarStyle: UIViewController? { nil }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
}
