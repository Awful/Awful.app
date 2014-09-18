//  ImageViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Downloads an image and shows it in a zoomable scroll view for inspection and further action.
class ImageViewController: AwfulViewController {
    let URL: NSURL!
    var doneAction: (() -> Void)?
    private var downloadTask: NSURLSessionTask!
    private var imageData: NSData?
    private var showingOverlaidViews: Bool = false
    private var flashTimer: NSTimer?
    private var visible: Bool = false
    
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private var swipeGestureRecognizer: UISwipeGestureRecognizer!
    @IBOutlet private var overlaidViews: [UIView]!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var statusBarBackgroundViewHeightConstraint: NSLayoutConstraint!

    init(URL: NSURL) {
        self.URL = URL
        super.init(nibName: "ImageViewController", bundle: nil)
    }

    required init(coder: NSCoder) {
        fatalError("NSCoding is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.panGestureRecognizer.requireGestureRecognizerToFail(swipeGestureRecognizer)
        fetchImage()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        visible = true
        if imageData != nil {
            flashOverlaidViews()
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        visible = false
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
                    self.configureWithImageData(data)
                    self.actionButton.hidden = false
                    if self.visible {
                        self.flashOverlaidViews()
                    }
                }
                self.downloadTask = nil
            }
        }
        downloadTask.resume()
    }
    
    private func configureWithImageData(data: NSData) {
        activityIndicator.stopAnimating()
        imageData = data
        let animation = FVGifAnimation(data: data)
        if animation.canAnimate() {
            animation.setAnimationToImageView(imageView)
            imageView.startAnimating()
        } else {
            imageView.image = UIImage(data: data)
        }
        imageView.backgroundColor = UIColor.whiteColor()
        
        if let image = imageView.image ?? imageView.animationImages?[0] as UIImage? {
            let minimumZoom = CGSize(width: scrollView.bounds.width / image.size.width, height: scrollView.bounds.height / image.size.height)
            scrollView.minimumZoomScale = min(minimumZoom.width, minimumZoom.height, 1)
            scrollView.zoomScale = scrollView.minimumZoomScale
        } else {
            let alert = UIAlertController(title: "Missing or Invalid Image", message: "Could not find valid image data.") { action in
                self.dismiss()
            }
            presentViewController(alert, animated: true, completion: nil)
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
        let activityViewController = UIActivityViewController(activityItems: [imageData!], applicationActivities: nil)
        presentViewController(activityViewController, animated: true, completion: nil)
        let popover = activityViewController.popoverPresentationController
        popover?.sourceView = sender
        popover?.sourceRect = sender.bounds
    }
    
    @IBAction func didTapDone(sender: UIButton) {
        dismiss()
    }
    
    @IBAction func didSwipeDown(sender: UISwipeGestureRecognizer) {
        dismiss()
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

private class ContentCenteringScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        if let contentView = delegate?.viewForZoomingInScrollView?(self) {
            var frame = contentView.frame
            if frame.width < bounds.width {
                frame.origin.x = (bounds.width - frame.width) / 2
            } else {
                frame.origin.x = 0
            }
            if frame.height < bounds.height {
                frame.origin.y = (bounds.height - frame.height) / 2
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
