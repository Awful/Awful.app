import UIKit

/// Lightweight replacement for the old Toast helper that was removed during the SwiftUI migration.
/// The implementation is extremely simple: it shows a `UILabel` briefly at the bottom of the window.
/// If you need a fancier look, replace this with something more sophisticated later.
struct Toast {
    enum Icon {
        case link, bookmark, bookmarkSlash

        var systemImageName: String {
            switch self {
            case .link: return "link"
            case .bookmark: return "bookmark"
            case .bookmarkSlash: return "bookmark.slash"
            }
        }
    }

    /// Presents a temporary toast banner at the bottom of the key window.
    /// - Parameters:
    ///   - title: The message to display.
    ///   - icon:  A visual hint for the message. Unused for now but kept to match previous API.
    static func show(title: String, icon: Icon) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else { return }

        let label = PaddingLabel()
        label.text = title
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.backgroundColor = UIColor(white: 0, alpha: 0.8)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(label)

        let horizontalPadding: CGFloat = 16
        let bottomPadding: CGFloat = 40
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: horizontalPadding),
            window.trailingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: horizontalPadding),
            label.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -bottomPadding)
        ])

        label.alpha = 0
        UIView.animate(withDuration: 0.25, animations: {
            label.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 2, options: [], animations: {
                label.alpha = 0
            }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}

/// Simple UILabel subclass that adds some insets so the background looks nicer.
private final class PaddingLabel: UILabel {
    private let insets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
} 