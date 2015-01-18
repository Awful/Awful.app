//  ThreadTagNode.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Shows a placeholder thread tag while loading the actual thread tag via AwfulThreadTagLoader.
final class ThreadTagNode: ASImageNode {
    private let spin = Spinlock()
    private var _missingTagImage: UIImage?
    private var _tagImageName: String?
    private var tagImageLoaded = false
    
    // MARK: Public API, use that lock.
    
    /// An image to show when the actual thread tag image is unavailable.
    var missingTagImage: UIImage? {
        get {
            return spin.lock { self._missingTagImage }
        }
        set {
            spin.lock {
                if newValue == self._missingTagImage { return }
                
                self._missingTagImage = newValue
                if !self.tagImageLoaded {
                    self.image = self._missingTagImage
                }
            }
        }
    }
    
    /// The name of the actual thread tag image, to be lazy-loaded.
    var tagImageName: String? {
        get {
            return spin.lock { self._tagImageName }
        }
        set {
            spin.lock {
                if newValue == self._tagImageName { return }
                
                self._tagImageName = newValue
                self.tagImageLoaded = false
                self.stopObservingNewTagImages()
                
                if self.nodeLoaded {
                    self.lazilyLoadTagImage()
                }
            }
        }
    }
    
    override func displayWillStart() {
        super.displayWillStart()
        
        spin.lock {
            self.lazilyLoadTagImage()
        }
    }
    
    // MARK: Private API, assumes lock held by caller.
    
    private func lazilyLoadTagImage() {
        if tagImageLoaded { return }
        
        if let imageName = _tagImageName {
            dispatch_main_async {
                self.spin.lock {
                    if let tagImage = AwfulThreadTagLoader.imageNamed(imageName) {
                        self.tagImageLoaded = true
                        self.image = tagImage
                    } else {
                        self.startObservingNewTagImages()
                    }
                }
            }
        }
    }
    
    private var observer: AnyObject?
    
    private func startObservingNewTagImages() {
        if observer == nil {
            observer = NSNotificationCenter.defaultCenter().addObserverForName(AwfulThreadTagLoaderNewImageAvailableNotification, object: nil, queue: nil) { [unowned self] note in
                if let newImageName = note.userInfo?[AwfulThreadTagLoaderNewImageNameKey] as? String {
                    if newImageName == self.tagImageName {
                        self.spin.lock {
                            self.lazilyLoadTagImage()
                            self.stopObservingNewTagImages()
                        }
                    }
                }
            }
        }
    }
    
    private func stopObservingNewTagImages() {
        if let token: AnyObject = observer {
            NSNotificationCenter.defaultCenter().removeObserver(token)
            observer = nil
        }
    }
    
    deinit {
        stopObservingNewTagImages()
    }
}
