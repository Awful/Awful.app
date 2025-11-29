//  LoadingView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import FLAnimatedImage
import UIKit
import Lottie

/// A view that covers its superview with an indeterminate progress indicator.
class LoadingView: UIView {

    // MARK: - Constants

    /// Duration in seconds before showing the exit button and status messages.
    /// 3 seconds gives users time to see loading begin while preventing accidental early dismissal.
    fileprivate static let statusElementsVisibilityDelay: TimeInterval = 3.0

    // MARK: - Properties

    fileprivate let theme: Theme?

    fileprivate init(theme: Theme?) {
        self.theme = theme
        super.init(frame: .zero)
    }

    convenience init() {
        self.init(theme: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func loadingViewWithTheme(_ theme: Theme) -> LoadingView {
        switch theme[string: "postsLoadingViewType"] {
        case "Macinyos"?:
            return MacinyosLoadingView(theme: theme)
        case "Winpos95"?:
            return Winpos95LoadingView(theme: theme)
        case "YOSPOS"?:
            return YOSPOSLoadingView(theme: theme)
        default:
            return DefaultLoadingView(theme: theme)
        }
    }

    /// Callback invoked when user dismisses the loading view via the X button.
    ///
    /// Use weak/unowned captures to avoid retain cycles:
    /// ```swift
    /// loadingView.onDismiss = { [weak self] in
    ///     self?.handleDismissal()
    /// }
    /// ```
    var onDismiss: (() -> Void)?

    /// Updates the status text displayed in the loading view.
    ///
    /// This method should be overridden in subclasses to implement status updates.
    /// The default implementation does nothing. Only the default loading view theme
    /// currently supports status updates.
    ///
    /// - Parameter text: The status message to display
    func updateStatus(_ text: String) {
        // Override in subclasses
    }

    fileprivate func retheme() {
        // nop
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        guard let newSuperview = newSuperview else { return }
        frame = CGRect(origin: .zero, size: newSuperview.bounds.size)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        retheme()
    }
}

private class DefaultLoadingView: LoadingView {

    private let animationView: LottieAnimationView
    private let statusLabel: UILabel
    private let showNowButton: UIButton
    private var visibilityTimer: Timer?

    override init(theme: Theme?) {
        animationView = LottieAnimationView(
            animation: LottieAnimation.named("mainthrobber60"),
            configuration: LottieConfiguration(renderingEngine: .mainThread))

        statusLabel = UILabel()
        showNowButton = UIButton(type: .system)

        super.init(theme: theme)

        // Setup animation view
        animationView.currentFrame = 0
        animationView.contentMode = .scaleAspectFit
        animationView.animationSpeed = 1
        animationView.isOpaque = true
        animationView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(animationView)

        // Setup status label
        statusLabel.text = "Loading..."
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.alpha = 0 // Initially hidden
        addSubview(statusLabel)

        // Setup Show Now button as X in circle icon
        let xCircleImage = UIImage(systemName: "xmark.circle.fill")
        showNowButton.setImage(xCircleImage, for: .normal)
        showNowButton.addTarget(self, action: #selector(showNowTapped), for: .touchUpInside)
        showNowButton.translatesAutoresizingMaskIntoConstraints = false
        showNowButton.contentHorizontalAlignment = .fill
        showNowButton.contentVerticalAlignment = .fill
        showNowButton.alpha = 0 // Initially hidden
        addSubview(showNowButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Animation centered, shifted up
            animationView.widthAnchor.constraint(equalToConstant: 90),
            animationView.heightAnchor.constraint(equalToConstant: 90),
            animationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),

            // Status label below animation
            statusLabel.topAnchor.constraint(equalTo: animationView.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            trailingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor, constant: 20),

            // Button below status (X icon)
            showNowButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            showNowButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            showNowButton.widthAnchor.constraint(equalToConstant: 32),
            showNowButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        animationView.play(fromFrame: 0, toFrame: 25, loopMode: .playOnce, completion: { [weak self] (finished) in
            if finished {
                // first animation complete! start second one and loop
                self?.animationView.play(fromFrame: 25, toFrame: .infinity, loopMode: .loop, completion: nil)
            } else {
               // animation cancelled
            }
        })
    }

    @objc private func showNowTapped() {
        onDismiss?()
    }

    override func updateStatus(_ text: String) {
        statusLabel.text = text
    }

    deinit {
        visibilityTimer?.invalidate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func retheme() {
        super.retheme()

        backgroundColor = theme?[uicolor: "postsLoadingViewTintColor"]
        if let tintColor = theme?[uicolor: "tintColor"] {
            animationView.setValueProvider(
                ColorValueProvider(tintColor.lottieColorValue),
                keypath: "**.Fill 1.Color"
            )
            showNowButton.tintColor = tintColor
        }

        // Apply text color to status label
        if let textColor = theme?[uicolor: "listTextColor"] {
            statusLabel.textColor = textColor
        }
    }
    
    fileprivate override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        if newSuperview != nil {
            // Invalidate any existing timer first to prevent race conditions
            visibilityTimer?.invalidate()
            // Start timer to show status and button after delay
            visibilityTimer = Timer.scheduledTimer(withTimeInterval: LoadingView.statusElementsVisibilityDelay, repeats: false) { [weak self] _ in
                self?.showStatusElements()
            }
        } else {
            // Clean up timer when view is removed
            visibilityTimer?.invalidate()
            visibilityTimer = nil
        }
    }

    private func showStatusElements() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.statusLabel.alpha = 1.0
            self?.showNowButton.alpha = 1.0
        }
    }
}

private class YOSPOSLoadingView: LoadingView {
    let label = UILabel()
    fileprivate var timer: Timer?
    
    override init(theme: Theme?) {
        super.init(theme: theme)
        
        backgroundColor = .black
        
        label.text = "|"
        label.font = UIFont(name: "Menlo", size: 15)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        label.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: label.trailingAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        timer?.invalidate()
    }
    
    override func retheme() {
        super.retheme()
        
        label.textColor = theme?["postsLoadingViewTintColor"]
        label.backgroundColor = backgroundColor
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview == nil {
            stopAnimating()
        } else {
            startAnimating()
        }
    }
    
    fileprivate func startAnimating() {
        stopAnimating()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true, block: { [unowned self] timer in
            self.advanceSpinner()
        })
    }
    
    fileprivate func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }
    
    fileprivate func advanceSpinner() {
        switch label.text {
        case "/"?: label.text = "-"
        case "-"?: label.text = "\\"
        case "\\"?: label.text = "|"
        default: label.text = "/"
        }
    }
}

private class MacinyosLoadingView: LoadingView {
    let imageView = UIImageView()
    
    override init(theme: Theme?) {
        super.init(theme: theme)
        
        if let wallpaper = UIImage(named: "macinyos-wallpaper") {
            backgroundColor = UIColor(patternImage: wallpaper)
        }
        
        imageView.image = UIImage(named: "macinyos-loading")
        imageView.contentMode = .center
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.black.cgColor
        imageView.layer.borderWidth = 1
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        
        imageView.widthAnchor.constraint(equalToConstant: 300).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 275).isActive = true
        imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class Winpos95LoadingView: LoadingView {
    let imageView = FLAnimatedImageView()
    var centerXConstraint: NSLayoutConstraint!
    var centerYConstraint: NSLayoutConstraint!
    
    override init(theme: Theme?) {
        super.init(theme: theme)
        
        backgroundColor = UIColor(red: 0.067, green: 0.502, blue: 0.502, alpha: 1)
        
        guard let imageURL = Bundle(for: Winpos95LoadingView.self).url(forResource: "hourglass.gif", withExtension: nil) else { fatalError("missing hourglass.gif") }
        guard let imageData = try? Data(contentsOf: imageURL) else { fatalError("couldn't load hourglass.gif") }
        imageView.animatedImage = FLAnimatedImage(animatedGIFData: imageData)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        centerXConstraint = imageView.centerXAnchor.constraint(equalTo: centerXAnchor)
        centerYConstraint = imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        [centerXConstraint, centerYConstraint].forEach { $0.isActive = true }
        
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func didPan(_ sender: UIPanGestureRecognizer) {
        guard sender.state == .began || sender.state == .changed else { return }
        let location = sender.location(in: self)
        centerXConstraint.constant = location.x - bounds.midX
        centerYConstraint.constant = location.y - bounds.midY
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview == nil {
            imageView.stopAnimating()
        } else {
            imageView.startAnimating()
        }
    }
}
