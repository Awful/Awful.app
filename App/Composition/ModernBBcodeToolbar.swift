//  ModernBBcodeToolbar.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import AwfulSettings

/// Actions that can be triggered from the modern toolbar
enum ModernToolbarAction {
    case url
    case image
    case format(BBcodeTagHelper.FormatOption)
    case video
}

/// Modern toolbar with quick access to BBcode formatting options
/// Uses Liquid Glass styling on iOS 26+, falls back to blur effect on older iOS
final class ModernBBcodeToolbar: UIView {

    // MARK: - Properties

    var onAction: ((ModernToolbarAction) -> Void)?

    var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet {
            updateKeyboardAppearance()
        }
    }

    var fontName: String? {
        didSet {
            updateButtonFonts()
        }
    }

    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [urlButton, imageButton, formatButton, videoButton])
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var urlButton: UIButton = {
        let button = createToolbarButton(title: "[url]")
        button.addTarget(self, action: #selector(didTapURL), for: .primaryActionTriggered)
        button.accessibilityLabel = "Insert URL tag"
        return button
    }()

    private lazy var imageButton: UIButton = {
        let button = createToolbarButton(title: "[img]")
        button.addTarget(self, action: #selector(didTapImage), for: .primaryActionTriggered)
        button.accessibilityLabel = "Insert image tag"
        return button
    }()

    private lazy var formatButton: UIButton = {
        let button = createToolbarButton(title: "Format")
        button.accessibilityLabel = "Text formatting options"
        button.showsMenuAsPrimaryAction = true
        button.menu = createFormatMenu()
        return button
    }()

    private lazy var videoButton: UIButton = {
        let button = createToolbarButton(title: "[video]")
        button.addTarget(self, action: #selector(didTapVideo), for: .primaryActionTriggered)
        button.accessibilityLabel = "Insert video tag"
        return button
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear

        addSubview(stackView)

        let buttonHeight: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 40 : 32

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            urlButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            imageButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            formatButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            videoButton.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])
    }

    // MARK: - Button Factory

    private func createToolbarButton(title: String) -> UIButton {
        if #available(iOS 26.0, *) {
            return GlassToolbarButton(title: title)
        } else {
            return BlurToolbarButton(title: title)
        }
    }

    // MARK: - Format Menu

    private func createFormatMenu() -> UIMenu {
        let actions = BBcodeTagHelper.FormatOption.allCases.map { option in
            UIAction(title: option.displayTitle, subtitle: option.menuTitle) { [weak self] _ in
                self?.triggerHaptic()
                self?.onAction?(.format(option))
            }
        }
        return UIMenu(title: "Format", children: actions)
    }

    // MARK: - Actions

    @objc private func didTapURL() {
        triggerHaptic()
        onAction?(.url)
    }

    @objc private func didTapImage() {
        triggerHaptic()
        onAction?(.image)
    }

    @objc private func didTapVideo() {
        triggerHaptic()
        onAction?(.video)
    }

    private func triggerHaptic() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Sizing

    override var intrinsicContentSize: CGSize {
        let height: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 52 : 44
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: - Appearance

    private func updateKeyboardAppearance() {
        // Only needed for pre-iOS 26 blur buttons
        if #available(iOS 26.0, *) {
            return
        }

        for button in [urlButton, imageButton, formatButton, videoButton] {
            if let blurButton = button as? BlurToolbarButton {
                blurButton.keyboardAppearance = keyboardAppearance
            }
        }
    }

    private func updateButtonFonts() {
        let font = UIFont.preferredFontForTextStyle(.footnote, fontName: fontName, sizeAdjustment: 0, weight: .medium)
        for button in [urlButton, imageButton, formatButton, videoButton] {
            if #available(iOS 26.0, *) {
                if let glassButton = button as? GlassToolbarButton {
                    glassButton.updateFont(font)
                }
            }
            if let blurButton = button as? BlurToolbarButton {
                blurButton.updateFont(font)
            }
        }
    }
}

// MARK: - iOS 26+ Glass Button

@available(iOS 26.0, *)
private final class GlassToolbarButton: UIButton {

    private let glassView: UIVisualEffectView
    private let titleLabelView: UILabel

    init(title: String) {
        let glassEffect = UIGlassEffect()
        glassView = UIVisualEffectView(effect: glassEffect)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.isUserInteractionEnabled = false
        glassView.layer.cornerRadius = 12
        glassView.layer.masksToBounds = true
        glassView.layer.cornerCurve = .continuous

        titleLabelView = UILabel()
        titleLabelView.translatesAutoresizingMaskIntoConstraints = false
        titleLabelView.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 0, weight: .medium)
        titleLabelView.text = title
        titleLabelView.textAlignment = .center
        titleLabelView.isUserInteractionEnabled = false

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        insertSubview(glassView, at: 0)
        glassView.contentView.addSubview(titleLabelView)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabelView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 8),
            titleLabelView.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -8),
            titleLabelView.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }

    func updateFont(_ font: UIFont) {
        titleLabelView.font = font
    }
}

// MARK: - Pre-iOS 26 Blur Button

private final class BlurToolbarButton: UIButton {

    private let blurView: UIVisualEffectView
    private let titleLabelView: UILabel

    var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet {
            updateAppearance()
        }
    }

    init(title: String) {
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = 10
        blurView.layer.masksToBounds = true
        blurView.layer.cornerCurve = .continuous

        titleLabelView = UILabel()
        titleLabelView.translatesAutoresizingMaskIntoConstraints = false
        titleLabelView.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 0, weight: .medium)
        titleLabelView.text = title
        titleLabelView.textAlignment = .center
        titleLabelView.isUserInteractionEnabled = false

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        insertSubview(blurView, at: 0)
        blurView.contentView.addSubview(titleLabelView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabelView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 8),
            titleLabelView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -8),
            titleLabelView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        let isDark = keyboardAppearance == .dark
        blurView.effect = UIBlurEffect(style: isDark ? .systemMaterialDark : .systemMaterial)
        titleLabelView.textColor = isDark ? .white : .label
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }

    func updateFont(_ font: UIFont) {
        titleLabelView.font = font
    }
}
