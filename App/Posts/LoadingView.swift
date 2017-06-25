//  LoadingView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage
import UIKit

/// A view that covers its superview with an indeterminate progress indicator.
class LoadingView: UIView {
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
    lazy var spinner: SpriteSheetView = {
        let image = UIImage(named: "v-throbber")!
        let view = SpriteSheetView(spriteSheet: image, followsTheme: true)
        view.frameRate = 30
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        
        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            self.centerYAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        
        return view
    }()
    
    override func retheme() {
        super.retheme()
        
        backgroundColor = theme?["postsLoadingViewTintColor"] as UIColor?
    }
    
    fileprivate override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        if newSuperview == nil {
            spinner.stopAnimating()
        } else {
            spinner.startAnimating()
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
        timer = Timer.scheduledTimerWithInterval(0.12, repeats: true, handler: { [unowned self] timer in
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
