//  ImageViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Downloads an image and shows it in a zoomable scroll view.
final class ImageViewController: UIViewController {
    private let imageURL: NSURL
    private var doneAction: (() -> Void)?
    private var downloadProgress: NSProgress!
    private var image: DecodedImage?
    private var rootView: RootView { return view as RootView }
    
    init(imageURL: NSURL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
        
        downloadProgress = downloadImage(imageURL, completion: didDownloadImage)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func didDownloadImage(image: DecodedImage) {
        self.image = image
        if isViewLoaded() {
            applyImage(image)
        }
    }
    
    private func applyImage(image: DecodedImage) {
        switch image {
        case .Animated, .Static:
            rootView.image = image
        case let .Error(error):
            let alert = UIAlertController(networkError: error, handler: { [unowned self] action in
                self.dismiss()
            })
            presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    private func dismiss() {
        downloadProgress.cancel()
        rootView.cancelHideOverlayAfterDelay()
        
        if let action = doneAction {
            action()
        } else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return image != nil && rootView.overlayHidden
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    @IBAction private func didTapDone() {
        dismiss()
    }
    
    @IBAction private func didTapAction(sender: UIButton) {
        rootView.cancelHideOverlayAfterDelay()
        let wrappedURL: AnyObject = CopyURLActivity.wrapURL(imageURL)
        // We need to provide the image data as the activity item so that animated GIFs stay animated.
        let activityViewController = UIActivityViewController(activityItems: [image!.data!, wrappedURL], applicationActivities: [CopyURLActivity()])
        presentViewController(activityViewController, animated: true, completion: nil)
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
    }
    
    // MARK: View lifecycle
    
    private class RootView: UIView, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        let scrollView = UIScrollView()
        let imageView = FLAnimatedImageView()
        let statusBarBackground = UIView()
        let doneButton = SlopButton()
        let actionButton = SlopButton()
        var overlayViews: [UIView] { return [statusBarBackground, doneButton, actionButton] }
        var overlayButtons: [UIButton] { return [doneButton, actionButton] }
        var overlayHidden = false
        var hideOverlayTimer: NSTimer?
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        let tap = UITapGestureRecognizer()
        let panToDismiss = UIPanGestureRecognizer()
        var panToDismissAction: (() -> Void)?
        let doubleTap = UITapGestureRecognizer()
        
        override init() {
            super.init(frame: CGRectZero)
            
            tap.addTarget(self, action: "didTapImage:")
            tap.requireGestureRecognizerToFail(doubleTap)
            addGestureRecognizer(tap)
            
            panToDismiss.addTarget(self, action: "didPanToDismiss:")
            panToDismiss.delegate = self
            addGestureRecognizer(panToDismiss)
            
            backgroundColor = UIColor.blackColor()
            
            scrollView.indicatorStyle = .White
            scrollView.delegate = self
            addSubview(scrollView)
            
            doubleTap.numberOfTapsRequired = 2
            doubleTap.addTarget(self, action: "didDoubleTap:")
            scrollView.addGestureRecognizer(doubleTap)
            
            // Many images include transparent regions that are assumed to reveal a vaguely white background.
            imageView.backgroundColor = UIColor.whiteColor()
            imageView.opaque = true
            scrollView.addSubview(imageView)
            
            let overlaidForegroundColor = UIColor.whiteColor()
            let overlaidBackgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
            let buttonCornerRadius: CGFloat = 8
            
            statusBarBackground.backgroundColor = overlaidBackgroundColor
            addSubview(statusBarBackground)
            
            let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptorWithTextStyle(UIFontTextStyleBody)
            let title = NSAttributedString(string: "Done", attributes: [
                NSForegroundColorAttributeName: overlaidForegroundColor,
                NSFontAttributeName: UIFont.boldSystemFontOfSize(bodyFontDescriptor.pointSize)
                ])
            doneButton.setAttributedTitle(title, forState: .Normal)
            doneButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
            doneButton.horizontalSlop = 10
            doneButton.verticalSlop = 20
            doneButton.backgroundColor = overlaidBackgroundColor
            doneButton.layer.cornerRadius = buttonCornerRadius
            addSubview(doneButton)

            actionButton.setImage(UIImage(named: "action"), forState: .Normal)
            actionButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 7, bottom: 7, right: 7)
            actionButton.horizontalSlop = 10
            actionButton.verticalSlop = 20
            actionButton.tintColor = overlaidForegroundColor
            actionButton.backgroundColor = overlaidBackgroundColor
            actionButton.layer.cornerRadius = buttonCornerRadius
            // Wait until image loads before allowing actions.
            actionButton.enabled = false
            actionButton.hidden = true
            addSubview(actionButton)
            
            spinner.startAnimating()
            addSubview(spinner)
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var image: DecodedImage? {
            didSet {
                if let image = image {
                    switch image {
                    case let .Animated(animatedImage):
                        imageView.animatedImage = animatedImage
                    case let .Static(image: image, data: data):
                        imageView.image = image
                    case .Error:
                        imageView.image = nil
                    }
                } else {
                    imageView.image = nil
                }
                
                if image != nil {
                    actionButton.enabled = true
                    actionButton.hidden = false
                    
                    hideOverlayAfterDelay()
                }
                
                spinner.stopAnimating()
                
                setNeedsLayout()
            }
        }
        
        private var didConfigureScrollView = false
        
        override func layoutSubviews() {
            scrollView.frame = bounds
            
            if !didConfigureScrollView {
                let scrollViewSize = scrollView.bounds.size
                if scrollViewSize.width > 0 && scrollViewSize.height > 0 {
                    if let imageSize = image?.size {
                        scrollView.contentSize = imageSize
                        // FLAnimatedImageView.sizeToFit() sometimes doesn't change the size?
                        imageView.frame = CGRect(origin: CGPointZero, size: imageSize)
                        
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
        
        private func layoutOverlay() {
            let statusBarFrame = UIApplication.sharedApplication().statusBarFrame
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
        
        func setOverlayHidden(hidden: Bool, animated: Bool) {
            overlayHidden = hidden
            
            for button in overlayButtons {
                button.enabled = !hidden
            }
            
            cancelHideOverlayAfterDelay()
            
            let duration = animated ? 0.3 : 0
            UIView.animateWithDuration(duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .BeginFromCurrentState, animations: {
                self.awful_viewController?.setNeedsStatusBarAppearanceUpdate()
                UIView.performWithoutAnimation {
                    self.layoutOverlay()
                }
                
                for view in self.overlayViews {
                    view.alpha = hidden ? 0 : 1
                }
                }, completion: nil)
        }
        
        func hideOverlayAfterDelay() {
            hideOverlayTimer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: "hideOverlayTimerDidFire:", userInfo: nil, repeats: false)
        }
        
        @objc private func hideOverlayTimerDidFire(timer: NSTimer) {
            setOverlayHidden(true, animated: true)
        }
        
        func cancelHideOverlayAfterDelay() {
            hideOverlayTimer?.invalidate()
            hideOverlayTimer = nil
        }
        
        // MARK: Gesture recognizers
        
        @IBAction private func didTapImage(sender: UITapGestureRecognizer) {
            if sender.state == .Ended {
                setOverlayHidden(!overlayHidden, animated: true)
            }
        }
        
        private var panStart: NSTimeInterval = 0
        
        @IBAction private func didPanToDismiss(sender: UIPanGestureRecognizer) {
            switch sender.state {
            case .Began:
                panStart = NSProcessInfo.processInfo().systemUptime
                
            case .Changed:
                let velocity = sender.velocityInView(self)
                if velocity.y < 0 || abs(velocity.x) > abs(velocity.y) {
                    sender.enabled = false
                    sender.enabled = true
                }
                
            case .Ended:
                let translation = sender.translationInView(self)
                if abs(translation.x) < 30 {
                    if translation.y > 60 {
                        if NSProcessInfo.processInfo().systemUptime - panStart < 0.5 {
                            panToDismissAction?()
                        }
                    }
                }
                
            default:
                break
            }
        }
        
        @IBAction private func didDoubleTap(sender: UITapGestureRecognizer) {
            cancelHideOverlayAfterDelay()
            
            if scrollView.zoomScale == scrollView.minimumZoomScale {
                let midpoint = sender.locationInView(scrollView)
                let halfSize = CGSize(width: scrollView.contentSize.width / 2, height: scrollView.contentSize.height / 2)
                let quarterImageCenteredAtMidpoint = CGRect(origin: midpoint, size: CGSizeZero).rectByInsetting(dx: -halfSize.width / 2, dy: -halfSize.height / 2)
                scrollView.zoomToRect(quarterImageCenteredAtMidpoint, animated: true)
            } else {
                scrollView.setZoomScale(1, animated: true)
            }
        }
        
        // MARK: UIGestureRecognizerDelegate
        
        private func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer == panToDismiss {
                return otherGestureRecognizer is UIPanGestureRecognizer
            }
            
            return false
        }
        
        // MARK: UIScrollViewDelegate
        
        func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        func scrollViewDidZoom(scrollView: UIScrollView) {
            centerImageInScrollView()
            
            // Setting the scroll view zoom scale can trigger a didZoom delegate call, which can cause us to hide the overlay almost immediately after becoming visible. So check for a completed scroll view configuration too.
            if !overlayHidden && didConfigureScrollView {
                setOverlayHidden(true, animated: true)
            }
        }
    }
    
    override func loadView() {
        view = RootView()
        
        rootView.doneButton.addTarget(self, action: "didTapDone", forControlEvents: .TouchUpInside)
        rootView.actionButton.addTarget(self, action: "didTapAction:", forControlEvents: .TouchUpInside)
        
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
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if image != nil {
            rootView.hideOverlayAfterDelay()
        }
    }
}

private enum DecodedImage {
    case Animated(FLAnimatedImage)
    case Static(image: UIImage, data: NSData)
    case Error(NSError)
    
    var data: NSData? {
        switch self {
        case let .Animated(animatedImage): return animatedImage.data
        case let .Static(_, data: data): return data
        case .Error: return nil
        }
    }
    
    var size: CGSize? {
        switch self {
        case let .Animated(animatedImage): return animatedImage.size
        case let .Static(image: image, _): return image.size
        case .Error: return nil
        }
    }
}

/// Downloads and decodes the image at the URL. Completion is called on the main thread.
private func downloadImage(URL: NSURL, #completion: DecodedImage -> Void) -> NSProgress {
    let done: DecodedImage -> () = { image in
        dispatch_async(dispatch_get_main_queue()) {
            completion(image)
        }
    }
    
    let progress = NSProgress(totalUnitCount: 2)
    
    let request = NSMutableURLRequest(URL: URL)
    request.addValue("image/*", forHTTPHeaderField: "Accept")
    
    let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data: NSData?, response: NSURLResponse?, error: NSError?) in
        ++progress.completedUnitCount
        
        if let error = error {
            return done(.Error(error))
        }
        
        if let response = response as? NSHTTPURLResponse {
            if !(200...299).contains(response.statusCode) {
                let error = NSError(domain: AwfulErrorDomain, code: AwfulErrorCodes.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "Request failed (\(response.statusCode))",
                    NSURLErrorFailingURLErrorKey: URL
                    ])
                return done(.Error(error))
            }
        }
        
        if let data = data {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
                if let animatedImage = FLAnimatedImage(animatedGIFData: data) {
                    ++progress.completedUnitCount
                    
                    return done(.Animated(animatedImage))
                }
                
                if let image = UIImage(data: data) {
                    // Force decoding in the background.
                    
                    UIGraphicsBeginImageContextWithOptions(image.size, false, 1)
                    
                    image.drawInRect(CGRect(origin: CGPointZero, size: image.size))
                    
                    if progress.cancelled {
                        UIGraphicsEndImageContext()
                        
                        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
                        return done(.Error(error))
                    }
                    
                    let decodedImage = UIGraphicsGetImageFromCurrentImageContext()
                    
                    UIGraphicsEndImageContext()
                    
                    ++progress.completedUnitCount
                    
                    return done(.Static(image: decodedImage, data: data))
                }
                
                let error = NSError(domain: AwfulErrorDomain, code: AwfulErrorCodes.badServerResponse, userInfo: [
                    NSLocalizedDescriptionKey: "Request failed (no image data)",
                    NSURLErrorFailingURLErrorKey: URL
                    ])
                return done(.Error(error))
            }
        } else {
            fatalError("No data and no error in data task callback")
        }
    }
    task.resume()
    
    progress.cancellationHandler = { task.cancel() }
    return progress
}

/// Adds a "Preview Image" activity which uses an ImageViewController. The image's URL needs to go through wrapURL() before being added to the activityItems array, and no other activities will see or attempt to use the URL.
final class ImagePreviewActivity: UIActivity {
    /// Prepares an image URL for use by an ImagePreviewActivity. Plain NSURL objects are not recognized by an ImagePreviewActivity!
    class func wrapImageURL(imageURL: NSURL) -> AnyObject {
        return ImageURLWrapper(imageURL)
    }
    
    private(set) var activityViewController: UIViewController!
    
    override func activityType() -> String? {
        return "com.awfulapp.Awful.ImagePreview"
    }
    
    override func activityTitle() -> String? {
        return "Preview Image"
    }
    
    override func activityImage() -> UIImage? {
        return UIImage(named: "quick-look")
    }
    
    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return any(activityItems) { $0 is ImageURLWrapper }
    }
    
    override func prepareWithActivityItems(activityItems: [AnyObject]) {
        let wrapper = first(activityItems) { $0 is ImageURLWrapper } as ImageURLWrapper
        let imageURL = wrapper.imageURL
        let imageViewController = ImageViewController(imageURL: imageURL)
        imageViewController.doneAction = { self.activityDidFinish(true) }
        activityViewController = imageViewController
    }
    
    private class ImageURLWrapper: NSObject {
        let imageURL: NSURL
        
        init(_ imageURL: NSURL) {
            self.imageURL = imageURL
            super.init()
        }
    }
}
