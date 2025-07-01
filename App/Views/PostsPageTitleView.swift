import SwiftUI
import AwfulTheming

struct PostsPageTitleView: View {
    let title: String
    let onComposeTapped: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"]!))
            
            Spacer()
            
            Button(action: onComposeTapped) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(Color(theme[uicolor: "navigationBarTextColor"]!))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PostsPageTitleView(
        title: "This is a very long thread title that should wrap to two lines",
        onComposeTapped: {}
    )
    .frame(width: 300)
    .padding()
    .background(Color.gray)
    .environment(\.theme, Theme.defaultTheme())
} 