import SwiftUI
import AwfulCore
import AwfulTheming

/// SwiftUI replacement for the Selectotron page picker
struct PostsPagePicker: View {
    let thread: AwfulThread
    let numberOfPages: Int
    let currentPage: Int
    let onPageSelected: (ThreadPage) -> Void
    let onGoToLastPost: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var selectedPageIndex: Int
    
    init(thread: AwfulThread, numberOfPages: Int, currentPage: Int, onPageSelected: @escaping (ThreadPage) -> Void, onGoToLastPost: @escaping () -> Void) {
        self.thread = thread
        self.numberOfPages = numberOfPages
        self.currentPage = currentPage
        self.onPageSelected = onPageSelected
        self.onGoToLastPost = onGoToLastPost
        self._selectedPageIndex = State(initialValue: max(0, currentPage - 1))
    }
    
    private var selectedPageNumber: Int {
        selectedPageIndex + 1
    }
    
    private var jumpButtonTitle: String {
        ThreadPage.specific(selectedPageNumber) == ThreadPage.specific(currentPage) ? "Reload" : "Jump"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Button row
            HStack(spacing: 0) {
                Button("First") {
                    dismiss()
                    onPageSelected(.first)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(titleBackgroundColor)
                .foregroundColor(textColor)
                
                Divider()
                    .background(separatorColor)
                
                Button(jumpButtonTitle) {
                    dismiss()
                    onPageSelected(.specific(selectedPageNumber))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(titleBackgroundColor)
                .foregroundColor(textColor)
                .font(.body.weight(.medium))
                
                Divider()
                    .background(separatorColor)
                
                Button("Last") {
                    dismiss()
                    onGoToLastPost()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(titleBackgroundColor)
                .foregroundColor(textColor)
            }
            .frame(height: 44)
            
            // Picker
            Picker("Page", selection: $selectedPageIndex) {
                ForEach(0..<max(1, numberOfPages), id: \.self) { index in
                    Text("\(index + 1)")
                        .foregroundColor(textColor)
                        .tag(index)
                }
            }
            .pickerStyle(.wheel)
            .background(backgroundColor)
        }
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(width: 320)
    }
    
    private var backgroundColor: Color {
        Color(theme[uicolor: "sheetBackgroundColor"] ?? UIColor.systemBackground)
    }
    
    private var titleBackgroundColor: Color {
        Color(theme[uicolor: "sheetTitleBackgroundColor"] ?? UIColor.systemGray6)
    }
    
    private var textColor: Color {
        Color(theme[uicolor: "sheetTextColor"] ?? UIColor.label)
    }
    
    private var separatorColor: Color {
        Color(theme[uicolor: "sheetSeparatorColor"] ?? UIColor.separator)
    }
}

/// Wrapper view to present the page picker as a popover on iPad and sheet on iPhone
struct PostsPagePickerPresenter: View {
    let thread: AwfulThread
    let numberOfPages: Int
    let currentPage: Int
    let onPageSelected: (ThreadPage) -> Void
    let onGoToLastPost: () -> Void
    
    @State private var isPresented = false
    
    var body: some View {
        Button("Present Picker") {
            isPresented = true
        }
        .popover(isPresented: $isPresented) {
            if #available(iOS 16.4, *) {
                PostsPagePicker(
                    thread: thread,
                    numberOfPages: numberOfPages,
                    currentPage: currentPage,
                    onPageSelected: onPageSelected,
                    onGoToLastPost: onGoToLastPost
                )
                .presentationCompactAdaptation(.popover) // Force popover on all devices
            } else {
                PostsPagePicker(
                    thread: thread,
                    numberOfPages: numberOfPages,
                    currentPage: currentPage,
                    onPageSelected: onPageSelected,
                    onGoToLastPost: onGoToLastPost
                )
            }
        }
    }
}

#Preview {
    let thread = AwfulThread()
    thread.title = "Sample Thread"
    
    return PostsPagePicker(
        thread: thread,
        numberOfPages: 10,
        currentPage: 5,
        onPageSelected: { page in
            print("Selected page: \(page)")
        },
        onGoToLastPost: {
            print("Go to last post")
        }
    )
    .environment(\.theme, Theme.defaultTheme())
} 
