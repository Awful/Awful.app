//  LoadingView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage
import UIKit

/// A view that covers its superview with an indeterminate progress indicator.
class LoadingView: UIView {
    private let theme: Theme?
    
    private init(theme: Theme?) {
        self.theme = theme
        super.init(frame: .zero)
    }
    
    convenience init() {
        self.init(theme: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func loadingViewWithTheme(theme: Theme) -> LoadingView {
        switch theme["postsLoadingViewType"] as String? {
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
    
    private func retheme() {
        // nop
    }
    
    override func willMoveToSuperview(newSuperview: UIView?) {
        guard let newSuperview = newSuperview else { return }
        frame = CGRect(origin: .zero, size: newSuperview.bounds.size)
        autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        retheme()
    }
}

private class DefaultLoadingView: LoadingView {
    lazy var spinner: UIImageView = {
        let image = UIImage.animatedImageNamed("v-throbber", duration: 1.53)
        let spinner = UIImageView(image: image)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(spinner)
        
        self.centerXAnchor.constraintEqualToAnchor(spinner.centerXAnchor).active = true
        self.centerYAnchor.constraintEqualToAnchor(spinner.centerYAnchor).active = true
        
        return spinner
    }()
    
    override func retheme() {
        super.retheme()
        
        let tint = theme?["postsLoadingViewTintColor"] as UIColor?
        backgroundColor = tint
        spinner.backgroundColor = tint
    }
    
    private override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        
        if newSuperview == nil {
            spinner.stopAnimating()
        } else {
            spinner.startAnimating()
        }
    }
}

private class YOSPOSLoadingView: LoadingView {
    let label = UILabel()
    private var timer: NSTimer?
    
    override init(theme: Theme?) {
        super.init(theme: theme)
        
        backgroundColor = .blackColor()
        
        label.text = "|"
        label.font = UIFont(name: "Menlo", size: 15)
        label.textAlignment = .Center
        label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(label)
        
        label.leadingAnchor.constraintEqualToAnchor(self.leadingAnchor).active = true
        self.trailingAnchor.constraintEqualToAnchor(label.trailingAnchor).active = true
        label.centerYAnchor.constraintEqualToAnchor(self.centerYAnchor).active = true
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
    
    override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        
        if newSuperview == nil {
            stopAnimating()
        } else {
            startAnimating()
        }
    }
    
    private func startAnimating() {
        stopAnimating()
        timer = NSTimer.scheduledTimerWithInterval(0.12, repeats: true, handler: { [unowned self] timer in
            self.advanceSpinner()
        })
    }
    
    private func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }
    
    private func advanceSpinner() {
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
        imageView.contentMode = .Center
        imageView.backgroundColor = .whiteColor()
        imageView.layer.borderColor = UIColor.blackColor().CGColor
        imageView.layer.borderWidth = 1
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        
        imageView.widthAnchor.constraintEqualToConstant(300).active = true
        imageView.heightAnchor.constraintEqualToConstant(275).active = true
        imageView.centerXAnchor.constraintEqualToAnchor(self.centerXAnchor).active = true
        imageView.centerYAnchor.constraintEqualToAnchor(self.centerYAnchor).active = true
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
        
        guard let imageURL = NSBundle(forClass: Winpos95LoadingView.self).URLForResource("hourglass.gif", withExtension: nil) else { fatalError("missing hourglass.gif") }
        guard let imageData = NSData(contentsOfURL: imageURL) else { fatalError("couldn't load hourglass.gif") }
        imageView.animatedImage = FLAnimatedImage(animatedGIFData: imageData)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        centerXConstraint = imageView.centerXAnchor.constraintEqualToAnchor(centerXAnchor)
        centerYConstraint = imageView.centerYAnchor.constraintEqualToAnchor(centerYAnchor)
        [centerXConstraint, centerYConstraint].forEach { $0.active = true }
        
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan)))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func didPan(sender: UIPanGestureRecognizer) {
        guard sender.state == .Began || sender.state == .Changed else { return }
        let location = sender.locationInView(self)
        centerXConstraint.constant = location.x - bounds.midX
        centerYConstraint.constant = location.y - bounds.midY
    }
    
    override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        
        if newSuperview == nil {
            imageView.stopAnimating()
        } else {
            imageView.startAnimating()
        }
    }
}
