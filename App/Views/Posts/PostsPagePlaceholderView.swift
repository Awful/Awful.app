import UIKit

class PostsPagePlaceholderView: UIView {

    private let renderView = UIView()
    private let topBar = UIView()
    private let toolbar = UIToolbar()
    private let loadingView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        addSubview(renderView)
        addSubview(topBar)
        addSubview(toolbar)
        addSubview(loadingView)

        NSLayoutConstraint.activate([
            renderView.topAnchor.constraint(equalTo: topAnchor),
            renderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            renderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            topBar.topAnchor.constraint(equalTo: topAnchor),
            topBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: renderView.topAnchor),
            toolbar.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: bottomAnchor),
            loadingView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func hideToolbar() {
        toolbar.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 