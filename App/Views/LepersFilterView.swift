//  LepersFilterView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import SwiftUI
import UIKit

/// The Leper's Colony "display options" sheet: filter the ban/probation list by Type, Admin, Month, and
/// Year — the same options the SA website's banlist form offers. Present it via
/// ``LepersFilterHostingController``. Options (admins, years) are supplied by the caller from the most
/// recently loaded page, so the sheet does no network of its own.
struct LepersFilterView: View {
    @SwiftUI.Environment(\.theme) private var theme
    @StateObject private var model: LepersFilterViewModel

    /// Dismisses the sheet (supplied by the hosting controller).
    let onExit: () -> Void
    /// Applies the chosen filter (and reloads page 1).
    let onApply: (LepersColonyFilter) -> Void

    init(
        filter: LepersColonyFilter,
        options: LepersColonyScrapeResult.FilterOptions?,
        onExit: @escaping () -> Void,
        onApply: @escaping (LepersColonyFilter) -> Void
    ) {
        _model = StateObject(wrappedValue: LepersFilterViewModel(filter: filter, options: options))
        self.onExit = onExit
        self.onApply = onApply
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme[color: "backgroundColor"]!.ignoresSafeArea()
                form
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Display Options")
                        .font(.headline)
                        .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onExit)
                        .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        model.reset()
                        onApply(model.filter)
                        onExit()
                    }
                    .liquidGlassBarButtonColor(theme[color: "navigationBarTextColor"])
                    .disabled(model.isDefault)
                }
            }
            .background(NavigationConfigurator(theme: theme))
        }
        .navigationViewStyle(.stack)
        .liquidGlassNavigationTint(theme[color: "tintColor"])
        .applyFontDesign(if: theme.roundedFonts)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 0) {
                    pickerRow("Type") { typePicker }
                    rowDivider
                    pickerRow("Admin") { adminPicker }
                    rowDivider
                    pickerRow("Month") { monthPicker }
                    rowDivider
                    pickerRow("Year") { yearPicker }
                }
                .background(theme[color: "sheetBackgroundColor"]!)
                .cornerRadius(12)

                Button {
                    onApply(model.filter)
                    onExit()
                } label: {
                    buttonLabel("Apply", background: theme[color: "tintColor"]!, foreground: .white)
                }
            }
            .padding()
        }
    }

    // MARK: Pieces

    private func pickerRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
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

    private func buttonLabel(_ title: String, background: Color, foreground: Color) -> some View {
        Text(title)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(12)
    }

    private var typePicker: some View {
        Picker("Type", selection: $model.selectedType) {
            ForEach(LepersColonyScrapeResult.PunishmentFilter.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
    }

    private var adminPicker: some View {
        Picker("Admin", selection: $model.selectedAdminID) {
            Text("All").tag(UserID?.none)
            ForEach(model.admins, id: \.id) { admin in
                Text(admin.username).tag(UserID?.some(admin.id))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
    }

    private var monthPicker: some View {
        Picker("Month", selection: $model.selectedMonth) {
            Text("Any").tag(Int?.none)
            ForEach(1...12, id: \.self) { month in
                Text(LepersFilterViewModel.monthNames[month - 1]).tag(Int?.some(month))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
    }

    private var yearPicker: some View {
        Picker("Year", selection: $model.selectedYear) {
            Text("Any").tag(Int?.none)
            // `String(year)` avoids the number formatter's grouping separator (e.g. "2,015").
            ForEach(model.years, id: \.self) { year in
                Text(String(year)).tag(Int?.some(year))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .tint(theme[color: "tintColor"])
    }
}

// MARK: - View model

@MainActor
final class LepersFilterViewModel: ObservableObject {
    @Published var selectedType: LepersColonyScrapeResult.PunishmentFilter
    @Published var selectedAdminID: UserID?
    @Published var selectedMonth: Int?
    @Published var selectedYear: Int?

    let admins: [LepersColonyScrapeResult.Admin]
    let years: [Int]

    static let monthNames = Calendar.current.monthSymbols

    init(filter: LepersColonyFilter, options: LepersColonyScrapeResult.FilterOptions?) {
        selectedType = filter.type
        selectedAdminID = filter.adminID
        selectedMonth = filter.month
        selectedYear = filter.year
        admins = options?.admins ?? []
        years = options?.years ?? []
    }

    var filter: LepersColonyFilter {
        LepersColonyFilter(adminID: selectedAdminID, type: selectedType, month: selectedMonth, year: selectedYear)
    }

    /// Whether no filter is applied (so there's nothing to clear).
    var isDefault: Bool {
        filter == LepersColonyFilter()
    }

    /// Resets every picker back to its unfiltered default.
    func reset() {
        selectedType = .any
        selectedAdminID = nil
        selectedMonth = nil
        selectedYear = nil
    }
}

// MARK: - Hosting controller

/// Hosts ``LepersFilterView`` as a themed medium sheet. Mirrors `ArchivesHostingController`.
final class LepersFilterHostingController: UIHostingController<AnyView> {

    init(
        filter: LepersColonyFilter,
        options: LepersColonyScrapeResult.FilterOptions?,
        onApply: @escaping (LepersColonyFilter) -> Void
    ) {
        super.init(rootView: AnyView(EmptyView()))
        rootView = AnyView(
            LepersFilterView(
                filter: filter,
                options: options,
                onExit: { [weak self] in self?.dismiss(animated: true) },
                onApply: onApply
            )
            .themed()
        )
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            if UIDevice.current.userInterfaceIdiom == .pad {
                sheet.selectedDetentIdentifier = .large
            }
        }
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationCapturesStatusBarAppearance = true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        let theme = Theme.defaultTheme()
        return (theme["statusBarBackground"] == "light") ? .darkContent : .lightContent
    }

    override var childForStatusBarStyle: UIViewController? { nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
}
