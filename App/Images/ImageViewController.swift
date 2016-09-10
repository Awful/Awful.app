//  ImageViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import FLAnimatedImage

/// Downloads an image and shows it in a zoomable scroll view.
final class ImageViewController: UIViewController {
    fileprivate let imageURL: URL
    fileprivate var doneAction: (() -> Void)?
    fileprivate var downloadProgress: Progress!
    fileprivate var image: DecodedImage?
    fileprivate var rootView: RootView { return view as! RootView }
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
        
        downloadProgress = downloadImage(imageURL, completion: didDownloadImage)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func didDownloadImage(_ image: DecodedImage) {
        self.image = image
        if isViewLoaded {
            applyImage(image)
        }
    }
    
    fileprivate func applyImage(_ image: DecodedImage) {
        switch image {
        case .animated, .static:
            rootView.image = image
        case let .error(error):
            let alert = UIAlertController(networkError: error, handler: { [unowned self] action in
                self.dismiss()
            })
            present(alert, animated: true, completion: nil)
        }
    }
    
    fileprivate func dismiss() {
        downloadProgress.cancel()
        rootView.cancelHideOverlayAfterDelay()
        
        if let action = doneAction {
            action()
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        return image != nil && rootView.overlayHidden
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    @IBAction @objc fileprivate func didTapDone() {
        dismiss()
    }
    
    @IBAction @objc fileprivate func didTapAction(_ sender: UIButton) {
        rootView.cancelHideOverlayAfterDelay()
        let wrappedURL: AnyObject = CopyURLActivity.wrapURL(imageURL)
        // We need to provide the image data as the activity item so that animated GIFs stay animated.
        var activityViewController: UIActivityViewController
        if (image == nil) {
            // Allow user to share the URL before the image has loaded fully, useful on slow connections
            activityViewController = UIActivityViewController(activityItems: [imageURL, wrappedURL], applicationActivities: [CopyURLActivity()])
            
            // Only use our copy button so it's clear they're copying the URL, not the image
            activityViewController.excludedActivityTypes = [UIActivityType.copyToPasteboard]
        } else {
            activityViewController = UIActivityViewController(activityItems: [image!.data!, wrappedURL], applicationActivities: [CopyURLActivity()])
            
        }
        present(activityViewController, animated: true, completion: nil)
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
    }
    
    // MARK: View lifecycle
    
    fileprivate class RootView: UIView, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        let scrollView = UIScrollView()
        let imageView = FLAnimatedImageView()
        let statusBarBackground = UIView()
        let doneButton = SlopButton()
        let actionButton = SlopButton()
        var overlayViews: [UIView] { return [statusBarBackground, doneButton, actionButton] }
        var overlayButtons: [UIButton] { return [doneButton, actionButton] }
        var overlayHidden = false
        var hideOverlayTimer: Timer?
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        let tap = UITapGestureRecognizer()
        let panToDismiss = UIPanGestureRecognizer()
        var panToDismissAction: (() -> Void)?
        let doubleTap = UITapGestureRecognizer()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            tap.addTarget(self, action: #selector(didTapImage))
            tap.require(toFail: doubleTap)
            addGestureRecognizer(tap)
            
            panToDismiss.addTarget(self, action: #selector(didPanToDismiss))
            panToDismiss.delegate = self
            addGestureRecognizer(panToDismiss)
            
            backgroundColor = UIColor.black
            
            scrollView.indicatorStyle = .white
            scrollView.delegate = self
            addSubview(scrollView)
            
            doubleTap.numberOfTapsRequired = 2
            doubleTap.addTarget(self, action: #selector(didDoubleTap))
            scrollView.addGestureRecognizer(doubleTap)
            
            // Many images include transparent regions that are assumed to reveal a vaguely white background.
            imageView.backgroundColor = UIColor.white
            imageView.isOpaque = true
            scrollView.addSubview(imageView)
            
            let overlaidForegroundColor = UIColor.white
            let overlaidBackgroundColor = UIColor.black.withAlphaComponent(0.7)
            let buttonCornerRadius: CGFloat = 8
            
            statusBarBackground.backgroundColor = overlaidBackgroundColor
            addSubview(statusBarBackground)
            
            let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.body)
            let title = NSAttributedString(string: "Done", attributes: [
                NSForegroundColorAttributeName: overlaidForegroundColor,
                NSFontAttributeName: UIFont.boldSystemFont(ofSize: bodyFontDescriptor.pointSize)
                ])
            doneButton.setAttributedTitle(title, for: UIControlState())
            doneButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
            doneButton.horizontalSlop = 10
            doneButton.verticalSlop = 20
            doneButton.backgroundColor = overlaidBackgroundColor
            doneButton.layer.cornerRadius = buttonCornerRadius
            addSubview(doneButton)

            actionButton.setImage(UIImage(named: "action"), for: UIControlState())
            actionButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 7, bottom: 7, right: 7)
            actionButton.horizontalSlop = 10
            actionButton.verticalSlop = 20
            actionButton.tintColor = overlaidForegroundColor
            actionButton.backgroundColor = overlaidBackgroundColor
            actionButton.layer.cornerRadius = buttonCornerRadius
            addSubview(actionButton)
            
            spinner.startAnimating()
            addSubview(spinner)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var image: DecodedImage? {
            didSet {
                if let image = image {
                    switch image {
                    case let .animated(animatedImage):
                        imageView.animatedImage = animatedImage
                    case let .static(image: image, data: _):
                        imageView.image = image
                    case .error:
                        imageView.image = nil
                    }
                } else {
                    imageView.image = nil
                }
                
                if image != nil {
                    actionButton.isEnabled = true
                    actionButton.isHidden = false
                    
                    hideOverlayAfterDelay()
                }
                
                spinner.stopAnimating()
                
                setNeedsLayout()
            }
        }
        
        fileprivate var didConfigureScrollView = false
        
        override func layoutSubviews() {
            scrollView.frame = bounds
            
            if !didConfigureScrollView {
                let scrollViewSize = scrollView.bounds.size
                if scrollViewSize.width > 0 && scrollViewSize.height > 0 {
                    if let imageSize = image?.size {
                        scrollView.contentSize = imageSize
                        // FLAnimatedImageView.sizeToFit() sometimes doesn't change the size?
                        imageView.frame = CGRect(origin: CGPoint.zero, size: imageSize)
                        
                        let fitsOnScreenZoomScale = min(scrollViewSize.width / imageSize.width, scrollViewSize.height / imageSize.height, 1)
                        scrollView.minimumZoomScale = fitsOnScreenZoomScale
                        scrollView.maximumZoomScale = 25 * fitsOnScreenZoomScale
                        scrollView.zoomScale = fitsOnScreenZoomScale
                        
                        didConfigureScrollView = true
                    }
                }
            }
            
            centerImageInScrollView()
            
            spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
            
            layoutOverlay()
        }
        
        fileprivate func layoutOverlay() {
            let statusBarFrame = UIApplication.shared.statusBarFrame
            // Status bar frame is in screen coordinates.
            let statusBarHeight = min(statusBarFrame.width, statusBarFrame.height)
            let typicalStatusBarHeight: CGFloat = 20
            let bonusStatusBarHeight = statusBarHeight - typicalStatusBarHeight
            // The in-call status bar bumps the whole window down past the typical status bar height, so we'll offset the status bar background by the same amount that the window was pushed down.
            statusBarBackground.frame = CGRect(x: 0, y: -bonusStatusBarHeight, width: bounds.width, height: statusBarHeight)
            
            doneButton.sizeToFit()
            let doneButtonSize = doneButton.bounds.size
            doneButton.frame = CGRect(origin: CGPoint(x: 10, y: statusBarBackground.frame.maxY + 20), size: doneButtonSize)
            
            actionButton.sizeToFit()
            let actionButtonSize = actionButton.bounds.size
            actionButton.frame = CGRect(origin: CGPoint(
                x: bounds.maxX - 10 - actionButtonSize.width,
                y: bounds.maxY - 20 - actionButtonSize.height),
                size: actionButtonSize)
        }
        
        func centerImageInScrollView() {
            // Thanks for the idea to use contentInset! http://petersteinberger.com/blog/2013/how-to-center-uiscrollview/
            let contentSize = scrollView.contentSize
            let scrollViewSize = scrollView.bounds.size

            var horizontal: CGFloat = 0
            if contentSize.width < scrollViewSize.width {
                horizontal = (scrollViewSize.width - contentSize.width) / 2
            }

            var vertical: CGFloat = 0
            if contentSize.height < scrollViewSize.height {
                vertical = (scrollViewSize.height - contentSize.height) / 2
            }

            scrollView.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        }
        
        func setOverlayHidden(_ hidden: Bool, animated: Bool) {
            overlayHidden = hidden
            
            for button in overlayButtons {
                button.isEnabled = !hidden
            }
            
            cancelHideOverlayAfterDelay()
            
            let duration = animated ? 0.3 : 0
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
                self.nearestViewController?.setNeedsStatusBarAppearanceUpdate()
                UIView.performWithoutAnimation {
                    self.layoutOverlay()
                }
                
                for view in self.overlayViews {
                    view.alpha = hidden ? 0 : 1
                }
                }, completion: nil)
        }
        
        func hideOverlayAfterDelay() {
            hideOverlayTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(RootView.hideOverlayTimerDidFire(_:)), userInfo: nil, repeats: false)
        }
        
        @objc fileprivate func hideOverlayTimerDidFire(_ timer: Timer) {
            setOverlayHidden(true, animated: true)
        }
        
        func cancelHideOverlayAfterDelay() {
            hideOverlayTimer?.invalidate()
            hideOverlayTimer = nil
        }
        
        // MARK: Gesture recognizers
        
        @IBAction @objc fileprivate func didTapImage(_ sender: UITapGestureRecognizer) {
            if sender.state == .ended {
                setOverlayHidden(!overlayHidden, animated: true)
            }
        }
        
        fileprivate var panStart: TimeInterval = 0
        
        @IBAction @objc fileprivate func didPanToDismiss(_ sender: UIPanGestureRecognizer) {
            switch sender.state {
            case .began:
                panStart = ProcessInfo.processInfo.systemUptime
                
            case .changed:
                let velocity = sender.velocity(in: self)
                if velocity.y < 0 || abs(velocity.x) > abs(velocity.y) {
                    sender.isEnabled = false
                    sender.isEnabled = true
                }
                
            case .ended:
                let translation = sender.translation(in: self)
                if abs(translation.x) < 30 {
                    if translation.y > 60 {
                        if ProcessInfo.processInfo.systemUptime - panStart < 0.5 {
                            panToDismissAction?()
                        }
                    }
                }
                
            default:
                break
            }
        }
        
        @IBAction @objc fileprivate func didDoubleTap(_ sender: UITapGestureRecognizer) {
            cancelHideOverlayAfterDelay()
            
            if scrollView.zoomScale == scrollView.minimumZoomScale {
                let midpoint = sender.location(in: scrollView)
                let halfSize = CGSize(width: scrollView.contentSize.width / 2, height: scrollView.contentSize.height / 2)
                let quarterImageCenteredAtMidpoint = CGRect(origin: midpoint, size: .zero).insetBy(dx: -halfSize.width / 2, dy: -halfSize.height / 2)
                scrollView.zoom(to: quarterImageCenteredAtMidpoint, animated: true)
            } else {
                scrollView.setZoomScale(1, animated: true)
            }
        }
        
        // MARK: UIGestureRecognizerDelegate
        
        @objc fileprivate func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer == panToDismiss {
                return otherGestureRecognizer is UIPanGestureRecognizer
            }
            
            return false
        }
        
        // MARK: UIScrollViewDelegate
        
        @objc func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        @objc func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImageInScrollView()
            
            // Setting the scroll view zoom scale can trigger a didZoom delegate call, which can cause us to hide the overlay almost immediately after becoming visible. So check for a completed scroll view configuration too.
            if !overlayHidden && didConfigureScrollView {
                setOverlayHidden(true, animated: true)
            }
        }
    }
    
    override func loadView() {
        view = RootView()
        
        rootView.doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        rootView.actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)
        
        rootView.panToDismissAction = { [weak self] in self?.dismiss(); return }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let image = self.image {
            applyImage(image)
        } else {
            rootView.spinner.startAnimating()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if image != nil {
            rootView.hideOverlayAfterDelay()
        }
    }
}

private enum DecodedImage {
    case animated(FLAnimatedImage)
    case `static`(image: UIImage, data: Data)
    case error(Error)
    
    var data: Data? {
        switch self {
        case let .animated(animatedImage): return animatedImage.data
        case let .static(_, data: data): return data
        case .error: return nil
        }
    }
    
    var size: CGSize? {
        switch self {
        case let .animated(animatedImage): return animatedImage.size
        case let .static(image: image, _): return image.size
        case .error: return nil
        }
    }
}

/// Downloads and decodes the image at the URL. Completion is called on the main thread.
private func downloadImage(_ url: URL, completion: @escaping (DecodedImage) -> Void) -> Progress {
    let done: (DecodedImage) -> Void = { image in
        DispatchQueue.main.async {
            completion(image)
        }
    }
    
    let progress = Progress(totalUnitCount: 2)
    
    var request = URLRequest(url: url)
    request.addValue("image/*", forHTTPHeaderField: "Accept")
    
    let task = URLSession.shared.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
        progress.completedUnitCount += 1
        
        if let error = error {
            return done(.error(error))
        }
        
        if let response = response as? HTTPURLResponse {
            if !(200...299).contains(response.statusCode) {
                let error = NSError(domain: AwfulErrorDomain, code: AwfulErrorCodes.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "Request failed (\(response.statusCode))",
                    NSURLErrorFailingURLErrorKey: url
                    ])
                return done(.error(error))
            }
        }
        
        if let data = data {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                if let animatedImage = FLAnimatedImage(animatedGIFData: data) {
                    progress.completedUnitCount += 1
                    
                    return done(.animated(animatedImage))
                }
                
                if let image = UIImage(data: data) {
                    // Force decoding in the background.
                    
                    UIGraphicsBeginImageContextWithOptions(image.size, false, 1)
                    
                    image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
                    
                    if progress.isCancelled {
                        UIGraphicsEndImageContext()
                        
                        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
                        return done(.error(error))
                    }
                    
                    let decodedImage = UIGraphicsGetImageFromCurrentImageContext()!
                    
                    UIGraphicsEndImageContext()
                    
                    progress.completedUnitCount += 1
                    
                    return done(.static(image: decodedImage, data: data))
                }
                
                let error = NSError(domain: AwfulErrorDomain, code: AwfulErrorCodes.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "Request failed (no image data)",
                    NSURLErrorFailingURLErrorKey: url
                    ])
                return done(.error(error))
            }
        } else {
            fatalError("No data and no error in data task callback")
        }
    }) 
    task.resume()
    
    progress.cancellationHandler = { task.cancel() }
    return progress
}

/// Adds a "Preview Image" activity which uses an ImageViewController. Add the activity both as an application activity and as one of the activity items.
final class ImagePreviewActivity: UIActivity {
    let imageURL: URL
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init()
    }
    
    override var activityViewController : UIViewController? {
        return _activityViewController
    }
    fileprivate var _activityViewController: UIViewController?
    
    override var activityType: UIActivityType? {
        return UIActivityType(rawValue: "com.awfulapp.Awful.ImagePreview")
    }
    
    override var activityTitle: String? {
        return "Preview Image"
    }
    
    override var activityImage: UIImage? {
        return UIImage(named: "quick-look")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return any(activityItems) { $0 as! NSObject == self }
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        let imageViewController = ImageViewController(imageURL: imageURL)
        imageViewController.doneAction = { self.activityDidFinish(true) }
        _activityViewController = imageViewController
    }
}
