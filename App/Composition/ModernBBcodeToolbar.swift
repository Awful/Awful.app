//  ModernBBcodeToolbar.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit
import AwfulSettings
import AwfulTheming

/// Actions that can be triggered from the modern toolbar
enum ModernToolbarAction {
    case url
    case image
    case format(BBcodeTagHelper.FormatOption)
    case video
    /// Only offered when composing a new thread; a poll attaches to the thread, not to a post.
    case poll
    /// Only offered when replying to the app's feedback thread; appends device/app diagnostics.
    case specs
}

/// Modern toolbar with quick access to BBcode formatting options
/// Uses Liquid Glass styling on iOS 26+, falls back to blur effect on older iOS
final class ModernBBcodeToolbar: UIView {

    // MARK: - Properties

    var onAction: ((ModernToolbarAction) -> Void)?

    /// Called when the keyboard toggle button is tapped. The toolbar's owner collapses or restores
    /// the keyboard and then sets `isKeyboardMinimized` so the glyph matches.
    var onToggleKeyboard: (() -> Void)?

    /// Whether the keyboard is collapsed to just the toolbars, which decides the toggle's glyph:
    /// a chevron pointing down to minimize, or a keyboard to bring it back.
    var isKeyboardMinimized = false {
        didSet {
            guard isKeyboardMinimized != oldValue, showsKeyboardToggleButton else { return }
            let name = isKeyboardMinimized ? Self.restoreKeyboardSymbolName : Self.minimizeKeyboardSymbolName
            if #available(iOS 26.0, *), let glass = keyboardToggleButton as? GlassToolbarButton {
                glass.updateSymbol(name)
            } else if let blur = keyboardToggleButton as? BlurToolbarButton {
                blur.updateSymbol(name)
            }
            keyboardToggleButton.accessibilityLabel = isKeyboardMinimized ? "Show keyboard" : "Minimize keyboard"
        }
    }

    /// Dims the keyboard toggle. Cleared while the system has collapsed the keyboard itself (a
    /// hardware keyboard is connected): nothing public brings the software keyboard back then, so
    /// the toggle shows the state but can't change it.
    var isKeyboardToggleEnabled = true {
        didSet {
            guard showsKeyboardToggleButton else { return }
            keyboardToggleButton.isEnabled = isKeyboardToggleEnabled
        }
    }

    /// Outlines the blur buttons (pre-iOS 26, or Reduce Liquid Glass) so they read as buttons
    /// against the keyboard, the way the banner toast outlines itself. Glass buttons have their
    /// own edge and ignore this.
    var strokeColor: UIColor? {
        didSet { updateButtonStrokes() }
    }

    private static let minimizeKeyboardSymbolName = "keyboard.chevron.compact.down"
    private static let restoreKeyboardSymbolName = "keyboard"

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

    /// Adds a Poll button to the toolbar. Only the new thread composer sets this: a poll belongs to
    /// a thread, so there's nothing to attach one to when replying or writing a private message.
    var showsPollButton = false {
        didSet {
            guard showsPollButton != oldValue else { return }
            setButton(pollButton, visible: showsPollButton, heightConstraint: pollButtonHeightConstraint)
        }
    }

    private lazy var pollButtonHeightConstraint = pollButton.heightAnchor.constraint(equalToConstant: Self.buttonHeight)

    /// Adds a Specs button to the toolbar. Only the reply composer for the app's feedback thread
    /// sets this: the button appends device/app diagnostics that help reproduce bug reports.
    var showsSpecsButton = false {
        didSet {
            guard showsSpecsButton != oldValue else { return }
            setButton(specsButton, visible: showsSpecsButton, heightConstraint: specsButtonHeightConstraint)
        }
    }

    private lazy var specsButtonHeightConstraint = specsButton.heightAnchor.constraint(equalToConstant: Self.buttonHeight)

    /// Adds or removes a conditionally-shown button. The height constraint is self-referential so
    /// it survives removal from the superview; activate the one made at init rather than stacking
    /// a duplicate every time the button comes back.
    private func setButton(_ button: UIButton, visible: Bool, heightConstraint: NSLayoutConstraint) {
        if visible {
            stackView.addArrangedSubview(button)
            heightConstraint.isActive = true
        } else {
            stackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        updateKeyboardAppearance()
        updateButtonFonts()
        updateButtonStrokes()
    }

    /// Marks the Poll button to show the thread already has a poll attached.
    var pollIsAttached = false {
        didSet {
            guard pollIsAttached != oldValue else { return }
            let title = pollIsAttached ? "Poll \u{2713}" : "Poll"
            if #available(iOS 26.0, *), let glass = pollButton as? GlassToolbarButton {
                glass.updateTitle(title)
            } else if let blur = pollButton as? BlurToolbarButton {
                blur.updateTitle(title)
            }
        }
    }

    private static var buttonHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 40 : 32
    }

    /// Every button currently in the toolbar, for appearance updates.
    private var allButtons: [UIButton] {
        var buttons = [urlButton, imageButton, formatButton, videoButton]
        if showsPollButton { buttons.append(pollButton) }
        if showsSpecsButton { buttons.append(specsButton) }
        if showsKeyboardToggleButton { buttons.append(keyboardToggleButton) }
        return buttons
    }

    /// Whether a keyboard toggle button sits at the trailing end of the toolbar. The iPad keyboard
    /// has its own dismiss key (and Catalyst has no soft keyboard), so it's only on iPhone, where
    /// there is otherwise no way to get the keyboard out of the way short of dismissing the sheet.
    private let showsKeyboardToggleButton = UIDevice.current.userInterfaceIdiom == .phone

    private lazy var keyboardToggleButton: UIButton = {
        let button = createToolbarButton(symbolName: Self.minimizeKeyboardSymbolName)
        button.addTarget(self, action: #selector(didTapKeyboardToggle), for: .primaryActionTriggered)
        button.accessibilityLabel = "Minimize keyboard"
        return button
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [urlButton, imageButton, videoButton, formatButton])
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var pollButton: UIButton = {
        let button = createToolbarButton(title: "Poll")
        button.addTarget(self, action: #selector(didTapPoll), for: .primaryActionTriggered)
        button.accessibilityLabel = "Add a poll"
        return button
    }()

    private lazy var specsButton: UIButton = {
        let button = createToolbarButton(title: "Specs")
        button.addTarget(self, action: #selector(didTapSpecs), for: .primaryActionTriggered)
        button.accessibilityLabel = "Append device and app info"
        return button
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

        let buttonHeight = Self.buttonHeight

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            urlButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            imageButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            formatButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            videoButton.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])

        // The keyboard toggle is a square sibling of the stack, not an arranged subview, so the
        // stack's fillEqually distribution stays among the text buttons.
        if showsKeyboardToggleButton {
            addSubview(keyboardToggleButton)
            NSLayoutConstraint.activate([
                keyboardToggleButton.widthAnchor.constraint(equalToConstant: buttonHeight),
                keyboardToggleButton.heightAnchor.constraint(equalToConstant: buttonHeight),
                keyboardToggleButton.centerYAnchor.constraint(equalTo: stackView.centerYAnchor),
                keyboardToggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                stackView.trailingAnchor.constraint(equalTo: keyboardToggleButton.leadingAnchor, constant: -8),
            ])
        } else {
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12).isActive = true
        }
    }

    // MARK: - Button Factory

    private func createToolbarButton(title: String) -> UIButton {
        if #available(iOS 26.0, *), LiquidGlass.isEnabled {
            return GlassToolbarButton(title: title)
        } else {
            return BlurToolbarButton(title: title)
        }
    }

    private func createToolbarButton(symbolName: String) -> UIButton {
        if #available(iOS 26.0, *), LiquidGlass.isEnabled {
            return GlassToolbarButton(symbolName: symbolName)
        } else {
            return BlurToolbarButton(symbolName: symbolName)
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

    @objc private func didTapPoll() {
        triggerHaptic()
        onAction?(.poll)
    }

    @objc private func didTapSpecs() {
        triggerHaptic()
        onAction?(.specs)
    }

    @objc private func didTapKeyboardToggle() {
        triggerHaptic()
        onToggleKeyboard?()
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
        // Only needed for the blur buttons (pre-iOS 26, or Liquid Glass disabled)
        if #available(iOS 26.0, *), LiquidGlass.isEnabled {
            return
        }

        for button in allButtons {
            if let blurButton = button as? BlurToolbarButton {
                blurButton.keyboardAppearance = keyboardAppearance
            }
        }
    }

    private func updateButtonStrokes() {
        for button in allButtons {
            if let blurButton = button as? BlurToolbarButton {
                blurButton.updateStroke(strokeColor)
            }
        }
    }

    private func updateButtonFonts() {
        let font = UIFont.preferredFontForTextStyle(.footnote, fontName: fontName, sizeAdjustment: 0, weight: .medium)
        for button in allButtons {
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

// MARK: - Button content

/// What a toolbar button shows: a BBcode-ish title, or an SF Symbol for the icon-only buttons.
private enum ToolbarButtonContent {
    case title(String)
    case symbol(String)

    /// The view to centre in the button's glass or blur backdrop.
    func makeView() -> UIView {
        switch self {
        case .title(let title):
            let label = UILabel()
            label.font = UIFont.preferredFontForTextStyle(.footnote, sizeAdjustment: 0, weight: .medium)
            label.text = title
            label.textAlignment = .center
            // A fifth button (Poll or Specs) makes each one narrower; shrink rather than truncate "[video]".
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.75
            return label
        case .symbol(let name):
            let imageView = UIImageView(image: Self.symbolImage(named: name))
            imageView.contentMode = .center
            return imageView
        }
    }

    static func symbolImage(named name: String) -> UIImage? {
        let config = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        return UIImage(systemName: name, withConfiguration: config)
    }
}

// MARK: - iOS 26+ Glass Button

@available(iOS 26.0, *)
private final class GlassToolbarButton: UIButton {

    private let glassView: UIVisualEffectView
    private let content: UIView
    private var titleLabelView: UILabel? { content as? UILabel }

    convenience init(title: String) {
        self.init(content: .title(title))
    }

    convenience init(symbolName: String) {
        self.init(content: .symbol(symbolName))
    }

    private init(content spec: ToolbarButtonContent) {
        let glassEffect = UIGlassEffect()
        glassView = UIVisualEffectView(effect: glassEffect)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.isUserInteractionEnabled = false
        glassView.layer.cornerRadius = 12
        glassView.layer.masksToBounds = true
        glassView.layer.cornerCurve = .continuous

        content = spec.makeView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.isUserInteractionEnabled = false
        content.tintColor = .label

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        insertSubview(glassView, at: 0)
        glassView.contentView.addSubview(content)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),

            content.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -8),
            content.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { updateAlpha(animated: true) }
    }

    override var isEnabled: Bool {
        didSet { updateAlpha(animated: false) }
    }

    private func updateAlpha(animated: Bool) {
        let alpha: CGFloat = isHighlighted ? 0.6 : (isEnabled ? 1.0 : 0.4)
        UIView.animate(withDuration: animated ? 0.1 : 0) {
            self.alpha = alpha
        }
    }

    func updateFont(_ font: UIFont) {
        titleLabelView?.font = font
    }

    func updateTitle(_ title: String) {
        titleLabelView?.text = title
    }

    func updateSymbol(_ name: String) {
        (content as? UIImageView)?.image = ToolbarButtonContent.symbolImage(named: name)
    }
}

// MARK: - Pre-iOS 26 Blur Button

private final class BlurToolbarButton: UIButton {

    private let blurView: UIVisualEffectView
    private let content: UIView
    private var titleLabelView: UILabel? { content as? UILabel }

    var keyboardAppearance: UIKeyboardAppearance = .default {
        didSet {
            updateAppearance()
        }
    }

    convenience init(title: String) {
        self.init(content: .title(title))
    }

    convenience init(symbolName: String) {
        self.init(content: .symbol(symbolName))
    }

    private init(content spec: ToolbarButtonContent) {
        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = 10
        blurView.layer.masksToBounds = true
        blurView.layer.cornerCurve = .continuous

        content = spec.makeView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.isUserInteractionEnabled = false

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        insertSubview(blurView, at: 0)
        blurView.contentView.addSubview(content)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            content.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -8),
            content.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        let isDark = keyboardAppearance == .dark
        blurView.effect = UIBlurEffect(style: isDark ? .systemMaterialDark : .systemMaterial)
        let foreground: UIColor = isDark ? .white : .label
        titleLabelView?.textColor = foreground
        content.tintColor = foreground
    }

    override var isHighlighted: Bool {
        didSet { updateAlpha(animated: true) }
    }

    override var isEnabled: Bool {
        didSet { updateAlpha(animated: false) }
    }

    private func updateAlpha(animated: Bool) {
        let alpha: CGFloat = isHighlighted ? 0.6 : (isEnabled ? 1.0 : 0.4)
        UIView.animate(withDuration: animated ? 0.1 : 0) {
            self.alpha = alpha
        }
    }

    func updateFont(_ font: UIFont) {
        titleLabelView?.font = font
    }

    func updateTitle(_ title: String) {
        titleLabelView?.text = title
    }

    func updateSymbol(_ name: String) {
        (content as? UIImageView)?.image = ToolbarButtonContent.symbolImage(named: name)
    }

    func updateStroke(_ color: UIColor?) {
        blurView.layer.borderWidth = color == nil ? 0 : 1
        blurView.layer.borderColor = color?.cgColor
    }
}
