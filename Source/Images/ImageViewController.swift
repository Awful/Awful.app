//  ImageViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Downloads an image and shows it in a zoomable scroll view for inspection and further action.
final class ImageViewController: AwfulViewController {
    let URL: NSURL
    var doneAction: (() -> Void)?
    private var downloadTask: NSURLSessionTask!
    private var imageData: NSData?
    private var showingOverlaidViews: Bool = false
    private var flashTimer: NSTimer?
    
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var imageView: FLAnimatedImageView!
    @IBOutlet private var overlaidViews: [UIView]!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var statusBarBackgroundViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var panToDismissGestureRecognizer: UIPanGestureRecognizer!

    init(URL: NSURL) {
        self.URL = URL
        super.init(nibName: "ImageViewController", bundle: nil)
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchImage()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if imageData != nil {
            flashOverlaidViews()
        }
    }
    
    private enum DecodedImage {
        case Animated(FLAnimatedImage)
        case Static(UIImage)
        case Error
    }
    
    private func fetchImage() {
        let request = NSMutableURLRequest(URL: URL)
        request.addValue("image/*", forHTTPHeaderField: "Accept")
        downloadTask = NSURLSession.sharedSession().dataTaskWithRequest(request) { [unowned self] data, response, error in
            dispatch_async(dispatch_get_main_queue()) {
                if let error = error {
                    let alert = UIAlertController(networkError: error) { action in
                        self.dismiss()
                    }
                    self.presentViewController(alert, animated: true, completion: nil)
                } else {
                    self.decodeImage(data) { image in
                        self.imageData = data
                        self.configureWithImage(image)
                    }
                }
                self.downloadTask = nil
            }
        }
        downloadTask.resume()
    }
    
    private func decodeImage(data: NSData, completionBlock: (DecodedImage) -> Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var image: DecodedImage
            if let animatedImage = FLAnimatedImage(animatedGIFData: data) {
                image = .Animated(animatedImage)
            } else if let staticImage = UIImage(data: data) {
                image = .Static(staticImage)
            } else {
                image = .Error
            }
            dispatch_async(dispatch_get_main_queue()) {
                completionBlock(image)
            }
        }
    }
    
    private func configureWithImage(image: DecodedImage) {
        activityIndicator.stopAnimating()
        self.actionButton.hidden = false
        
        switch image {
        case .Animated(let animatedImage):
            imageView.animatedImage = animatedImage
        case .Static(let image):
            imageView.image = image
        case .Error:
            let alert = UIAlertController(title: "Missing or Invalid Image", message: "Could not find valid image data.") { action in
                self.dismiss()
            }
            presentViewController(alert, animated: true, completion: nil)
            return
        }
        imageView.backgroundColor = UIColor.whiteColor()
        if let imageSize = imageView.image?.size {
            let minimumZoom = CGSize(width: scrollView.bounds.width / imageSize.width, height: scrollView.bounds.height / imageSize.height)
            scrollView.minimumZoomScale = min(minimumZoom.width, minimumZoom.height, 1)
            scrollView.zoomScale = scrollView.minimumZoomScale
            scrollView.maximumZoomScale = 25 * scrollView.minimumZoomScale
        }
        
        if self.visible {
            flashOverlaidViews()
        }
    }
    
    private func dismiss() {
        if let task = downloadTask {
            task.cancel()
            downloadTask = nil
        }
        
        cancelFlashTimer()
        
        if let action = doneAction {
            action()
        } else {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }

    @IBAction func didTapImage(sender: UITapGestureRecognizer) {
        if sender.state == .Ended {
            cancelFlashTimer()
            setShowingOverlaidViews(!showingOverlaidViews, animated: true)
        }
    }

    @IBAction func didTapAction(sender: UIButton) {
        cancelFlashTimer()
        let wrappedURL: AnyObject = CopyURLActivity.wrapURL(URL)
        let activityViewController = UIActivityViewController(activityItems: [imageData!, wrappedURL], applicationActivities: [CopyURLActivity()])
        presentViewController(activityViewController, animated: true, completion: nil)
        let popover = activityViewController.popoverPresentationController
        popover?.sourceView = sender
        popover?.sourceRect = sender.bounds
    }
    
    @IBAction func didTapDone(sender: UIButton) {
        dismiss()
    }
    
    private var panStart: NSTimeInterval!
    
    @IBAction func didPanToDismiss(sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .Began:
            panStart = NSProcessInfo.processInfo().systemUptime
        case .Changed:
            let velocity = sender.velocityInView(view)
            if velocity.y < 0 || abs(velocity.x) > abs(velocity.y) {
                sender.enabled = false
                sender.enabled = true
            }
        case .Ended:
            let translation = sender.translationInView(view)
            if abs(translation.x) < 30 {
                if translation.y > 60 {
                    if NSProcessInfo.processInfo().systemUptime - panStart < 0.5 {
                        dismiss()
                    }
                }
            }
        default:
            break;
        }
    }
    
    private func setShowingOverlaidViews(showing: Bool, animated: Bool) {
        showingOverlaidViews = showing
        
        let targetAlpha: CGFloat = showingOverlaidViews ? 1 : 0
        UIView.animateWithDuration(animated ? 0.3 : 0, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .BeginFromCurrentState, animations: {
            
            // Can't get status bar height without showing it, but I want to animate the status bar along with the rest of the views.
            self.setNeedsStatusBarAppearanceUpdate()
            UIView.performWithoutAnimation() {
                let statusBarFrame = UIApplication.sharedApplication().statusBarFrame
                if statusBarFrame.height > 0 {
                    self.statusBarBackgroundViewHeightConstraint.constant = min(statusBarFrame.width, statusBarFrame.height)
                    self.view.layoutIfNeeded()
                }
            }
            
            for view in self.overlaidViews {
                view.alpha = targetAlpha
            }
            
        }, completion: nil)
    }
    
    private func flashOverlaidViews() {
        setShowingOverlaidViews(true, animated: true)
        flashTimer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: "flashTimerDidFire:", userInfo: nil, repeats: false)
    }
    
    @objc private func flashTimerDidFire(timer: NSTimer) {
        cancelFlashTimer()
        setShowingOverlaidViews(false, animated: true)
    }
    
    private func cancelFlashTimer() {
        flashTimer?.invalidate()
        flashTimer = nil
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return imageData != nil && !showingOverlaidViews
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
}

extension ImageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panToDismissGestureRecognizer {
            return true
        }
        fatalError("unexpected gesture recognizer")
    }
}

private final class ContentCenteringScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if let contentView = delegate?.viewForZoomingInScrollView?(self) {
            var frame = contentView.frame
            if frame.width < bounds.width {
                frame.origin.x = round(bounds.width - frame.width) / 2
            } else {
                frame.origin.x = 0
            }
            if frame.height < bounds.height {
                frame.origin.y = round(bounds.height - frame.height) / 2
            } else {
                frame.origin.y = 0
            }
            contentView.frame = frame
        }
    }
}

extension ImageViewController: UIScrollViewDelegate {
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView {
        return imageView
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView!) {
        if showingOverlaidViews {
            setShowingOverlaidViews(false, animated: true)
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView!) {
        if showingOverlaidViews {
            setShowingOverlaidViews(false, animated: true)
        }
    }
}

/// Adds a "Preview Image" activity. The image's URL needs to go through wrapURL() before being added to the activityItems array, and no other activities will see or attempt to use the URL.
final class ImagePreviewActivity: UIActivity {
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
        let imageViewController = ImageViewController(URL: imageURL)
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

func any<S: SequenceType, T where T == S.Generator.Element>(sequence: S, includeElement: (T) -> Bool) -> Bool {
    return first(sequence, includeElement) != nil
}

func first<S: SequenceType, T where T == S.Generator.Element>(sequence: S, includeElement: (T) -> Bool) -> T? {
    for element in sequence {
        if includeElement(element) {
            return element
        }
    }
    return nil
}
