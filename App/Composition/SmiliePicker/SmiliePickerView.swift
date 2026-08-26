//  SmiliePickerView.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import SwiftUI
import Smilies

struct SmiliePickerView: View {
    @StateObject private var viewModel: SmilieSearchViewModel
    @SwiftUI.Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    @SwiftUI.Environment(\.theme) private var theme: Theme
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // Uniform pill height (fits two lines of .subheadline), scales with Dynamic Type
    @ScaledMetric(relativeTo: .subheadline) private var pillHeight: CGFloat = 50

    let onSmilieSelected: (Smilie) -> Void
    
    private var columnCount: Int {
        // Use 6 columns for regular size class (iPad), 4 for compact (iPhone)
        horizontalSizeClass == .regular ? 6 : 4
    }
    
    init(dataStore: SmilieDataStore, onSmilieSelected: @escaping (Smilie) -> Void) {
        self._viewModel = StateObject(wrappedValue: SmilieSearchViewModel(dataStore: dataStore))
        self.onSmilieSelected = onSmilieSelected
    }
    
    var body: some View {
        ZStack {
            theme[color: "sheetBackgroundColor"]!
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                searchBar
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else if let error = viewModel.loadError {
                    errorView(message: error)
                } else {
                    scrollContent
                }
            }
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }
    
    private var headerView: some View {
        HStack {
            Text("Smilies")
                .font(.headline)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .foregroundColor(theme[color: "sheetTextColor"]!)
            
            Spacer()
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme[color: "tintColor"]!)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(theme[color: "sheetBackgroundColor"]!)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.7))
            
            ZStack(alignment: .leading) {
                if viewModel.searchText.isEmpty {
                    Text("Search smilies…")
                        .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.5))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
                TextField("", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(theme[color: "sheetTextColor"]!)
                    .accentColor(theme[color: "tintColor"]!)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.7))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme[color: "sheetBackgroundColor"]!)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme[color: "listSeparatorColor"]!, lineWidth: 1)
                )
        )
        .padding()
    }
    
    private var scrollContent: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    if viewModel.searchText.isEmpty && !viewModel.allSmilies.isEmpty {
                        categoryChipRow(proxy: proxy, maxPillWidth: geometry.size.width * 0.5)
                    }

                    scrollingSections
                }
            }
        }
    }

    private var scrollingSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !viewModel.searchText.isEmpty {
                    searchResultsSection
                } else {
                    if !viewModel.recentlyUsedSmilies.isEmpty {
                        recentlyUsedSection
                    }
                    allSmiliesSection
                }
            }
            .padding(.horizontal)
        }
    }

    private var categoryTitles: [String] {
        var titles: [String] = []
        if !viewModel.recentlyUsedSmilies.isEmpty {
            titles.append(recentlyUsedSectionTitle)
        }
        titles.append(contentsOf: viewModel.allSmilies.map { $0.title })
        return titles
    }

    /// Namespaces section anchor ids so they can't collide with the pill row's own
    /// `ForEach` identities — `ScrollViewProxy.scrollTo` searches every scroll view
    /// under the reader, and a bare title would match the (already visible) pill.
    private func sectionAnchorID(_ title: String) -> String {
        "section-\(title)"
    }

    private func categoryChipRow(proxy: ScrollViewProxy, maxPillWidth: CGFloat) -> some View {
        // Alternate titles between the two rows so adjacent categories stay near each other
        let titles = categoryTitles
        let topRow = stride(from: 0, to: titles.count, by: 2).map { titles[$0] }
        let bottomRow = stride(from: 1, to: titles.count, by: 2).map { titles[$0] }

        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(topRow, id: \.self) { title in
                        categoryPill(title, proxy: proxy, maxWidth: maxPillWidth)
                    }
                }
                if !bottomRow.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(bottomRow, id: \.self) { title in
                            categoryPill(title, proxy: proxy, maxWidth: maxPillWidth)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        // Size to the two rows' content height; without this the surrounding layout
        // can compress the scroller and clip the bottom row
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
    }

    private func categoryPill(_ title: String, proxy: ScrollViewProxy, maxWidth: CGFloat) -> some View {
        Button(action: {
            // Deferring past the button's own transaction keeps scrollTo reliable on iOS 15
            DispatchQueue.main.async {
                withAnimation {
                    proxy.scrollTo(sectionAnchorID(title), anchor: .top)
                }
            }
        }) {
            Text(title)
                .font(.subheadline)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .foregroundColor(theme[color: "sheetTextColor"]!)
                .frame(maxWidth: maxWidth)
                .padding(.horizontal, 12)
                .frame(height: pillHeight)
                .background(
                    Capsule()
                        .fill(pillBackgroundColor)
                        .overlay(
                            Capsule()
                                .stroke(pillStrokeColor, lineWidth: 1)
                        )
                )
        }
    }

    private var pillBackgroundColor: Color {
        let fallback = theme.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
        return theme[color: "listSecondaryTextColor"]?.opacity(theme.isDark ? 0.25 : 0.2) ?? fallback
    }

    private var pillStrokeColor: Color {
        let fallback = theme.isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)
        return theme[color: "listSecondaryTextColor"]?.opacity(0.5) ?? fallback
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Results")
                .font(.title3)
                .fontWeight(.bold)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .foregroundColor(theme[color: "sheetTextColor"]!)
            
            if viewModel.searchResults.isEmpty {
                VStack(spacing: 10) {
                    Text("😕")
                        .font(.system(size: 50))
                        .opacity(0.5)
                    Text("No smilies found")
                        .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.6))
                        .font(.body)
                    Text("Try a different search term")
                        .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.5))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                smilieGrid(viewModel.searchResults)
            }
        }
    }
    
    private let recentlyUsedSectionTitle = "Recently Used"

    private var recentlyUsedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(recentlyUsedSectionTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundColor(theme[color: "sheetTextColor"]!)
                Spacer()
            }
            .padding(.bottom, 5)
            
            smilieGrid(viewModel.recentlyUsedSmilies)
        }
        .id(sectionAnchorID(recentlyUsedSectionTitle))
    }
    
    private var allSmiliesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(viewModel.allSmilies.enumerated()), id: \.element.title) { index, section in
                VStack(alignment: .leading, spacing: 10) {
                    if index > 0 {
                        Divider()
                            .background(theme[color: "listSeparatorColor"]!)
                            .padding(.vertical, 10)
                    }

                    Text(section.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        .foregroundColor(theme[color: "sheetTextColor"]!)
                        .padding(.bottom, 5)

                    smilieGrid(section.smilies)
                }
                .id(sectionAnchorID(section.title))
            }
        }
    }
    
    private func smilieGrid(_ smilies: [Smilie]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount), spacing: 12) {
            ForEach(smilies, id: \.objectID) { smilie in
                SmilieGridItem(smilie: smilie) {
                    handleSmilieTap(smilie)
                }
            }
        }
    }
    
    private func handleSmilieTap(_ smilie: Smilie) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        viewModel.updateLastUsedDate(for: smilie)
        onSmilieSelected(smilie)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(theme[color: "sheetTextColor"]!.opacity(0.5))
            
            Text(message)
                .font(.body)
                .foregroundColor(theme[color: "sheetTextColor"]!)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.loadSmilies()
            }) {
                Text("Retry")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme[color: "tintColor"]!)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
    }
}

#if DEBUG
import SwiftUI

struct SmiliePickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            SmiliePickerView(dataStore: .shared) { smilie in
                print("Selected: \(smilie.text ?? "")")
            }
            .environment(\.theme, Theme.defaultTheme())
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            SmiliePickerView(dataStore: .shared) { smilie in
                print("Selected: \(smilie.text ?? "")")
            }
            .environment(\.theme, Theme.theme(named: "dark")!)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
