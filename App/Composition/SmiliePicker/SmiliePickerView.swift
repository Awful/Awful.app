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
    @State private var visibleSections = 3 // Start by showing only first 3 sections
    @State private var hasLoadedAllSections = false
    
    let onSmilieSelected: (SmilieData) -> Void
    
    private var columnCount: Int {
        // Use 6 columns for regular size class (iPad), 4 for compact (iPhone)
        horizontalSizeClass == .regular ? 6 : 4
    }
    
    init(dataStore: SmilieDataStore, onSmilieSelected: @escaping (SmilieData) -> Void) {
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
                        .onAppear {
                            // Check if we already have all sections loaded from the start
                            if visibleSections >= viewModel.allSmilies.count {
                                hasLoadedAllSections = true
                            }
                        }
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
    
    private var recentlyUsedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recently Used")
                    .font(.title3)
                    .fontWeight(.bold)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundColor(theme[color: "sheetTextColor"]!)
                Spacer()
            }
            .padding(.bottom, 5)
            
            smilieGrid(viewModel.recentlyUsedSmilies)
        }
    }
    
    private var allSmiliesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            let sectionsToShow = Array(viewModel.allSmilies.prefix(visibleSections))
            
            ForEach(Array(sectionsToShow.enumerated()), id: \.element.title) { index, section in
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
            }
            
            // Show loading indicator if there are more sections to load
            if !hasLoadedAllSections && visibleSections < viewModel.allSmilies.count && !viewModel.allSmilies.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
                .onAppear {
                    // Load more sections when this view appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            let newVisibleSections = min(visibleSections + 3, viewModel.allSmilies.count)
                            visibleSections = newVisibleSections
                            if newVisibleSections >= viewModel.allSmilies.count {
                                hasLoadedAllSections = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func smilieGrid(_ smilies: [SmilieData]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount), spacing: 12) {
            ForEach(smilies) { smilieData in
                SmilieGridItem(smilieData: smilieData) {
                    handleSmilieTap(smilieData)
                }
            }
        }
    }
    
    private func handleSmilieTap(_ smilieData: SmilieData) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        viewModel.updateLastUsedDate(for: smilieData)
        onSmilieSelected(smilieData)
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

extension Theme {
    var isDark: Bool {
        keyboardAppearance == .dark
    }
}

#if DEBUG
import SwiftUI

struct SmiliePickerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            SmiliePickerView(dataStore: .shared) { smilie in
                print("Selected: \(smilie.text)")
            }
            .environment(\.theme, Theme.defaultTheme())
            .previewDisplayName("Light Mode")
            
            // Dark mode preview
            SmiliePickerView(dataStore: .shared) { smilie in
                print("Selected: \(smilie.text)")
            }
            .environment(\.theme, Theme.theme(named: "dark")!)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
