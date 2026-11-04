//  ProbationBannerView.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import Combine
import UIKit

/// A one-line "on probation until…" strip for the top of thread lists. Shows and hides itself as the stored probation notice changes or is dismissed.
final class ProbationBannerView: UIView {

    /// Called when the banner is tapped, typically to present `ProbationDetailView`.
    var onTap: (() -> Void)?

    /// Called after the banner shows or hides itself, so the host can re-measure its layout.
    var onVisibilityChange: (() -> Void)?

    @FoilDefaultStorageOptional(Settings.probationMessage) private var probationMessage
    @FoilDefaultStorageOptional(Settings.dismissedProbationMessage) private var dismissedProbationMessage
    private var cancellables: Set<AnyCancellable> = []

    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "title-probation"))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28),
        ])
        return imageView
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.accessibilityTraits = .button
        label.accessibilityHint = LocalizedString("probation.banner.accessibility-hint")
        return label
    }()

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
        button.accessibilityLabel = LocalizedString("probation.banner.dismiss")
        button.addTarget(self, action: #selector(didTapClose), for: .primaryActionTriggered)
        button.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])
        return button
    }()

    init() {
        super.init(frame: .zero)

        // The icon and close button sit at the edges, and the text is centred across the whole banner between them.
        for view in [iconView, label, closeButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        // Gives way before the label compresses, so long text shifts off centre rather than shrinking.
        let centered = label.centerXAnchor.constraint(equalTo: centerXAnchor)
        centered.priority = UILayoutPriority(UILayoutPriority.defaultHigh.rawValue - 1)
        // Hugs the tallest subview, since the vertical constraints are all inequalities.
        let compact = heightAnchor.constraint(equalToConstant: 0)
        compact.priority = .defaultLow
        NSLayoutConstraint.activate([
            compact,
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 6),
            centered,
            label.leadingAnchor.constraint(greaterThanOrEqualTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),
            label.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 2),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        accessibilityElements = [label, closeButton]

        update()

        $probationMessage.combineLatest($dismissedProbationMessage)
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ theme: Theme) {
        // Shares the archives banner's colours so the two notices read as the same kind of thing.
        backgroundColor = theme[uicolor: "archivesBannerBackgroundColor"]
        label.textColor = theme[uicolor: "archivesBannerTextColor"]
        label.font = UIFont.preferredFontForTextStyle(.body, weight: .semibold)
        closeButton.tintColor = theme[uicolor: "archivesBannerTextColor"]
    }

    private func update() {
        label.text = ProbationNoticeStore.current?.localizedSummary
        let shouldHide = !ProbationNoticeStore.shouldShowBanner
        guard isHidden != shouldHide else { return }
        isHidden = shouldHide
        onVisibilityChange?()
    }

    @objc private func didTap() {
        onTap?()
    }

    @objc private func didTapClose() {
        ProbationNoticeStore.dismissCurrent()
    }
}
