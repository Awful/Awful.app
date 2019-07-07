// Public domain. https://github.com/nolanw/ImgurAnonymousAPI

import ImgurAnonymousAPI
import Photos
import SafariServices
import UIKit

final class ViewController: UIViewController {
    
    private var clientID: String = UserDefaults.standard.imgurClientID ?? ""
    private var imagePickerInfo: [UIImagePickerController.InfoKey: Any]?
    private var link: URL?
    private var progress: Progress?
    private var uploader: ImgurUploader?

    @IBOutlet private var checkRateLimitButton: UIButton?
    @IBOutlet private var clientIDTextField: UITextField?
    @IBOutlet private var imageButton: UIButton?
    @IBOutlet private var resultsTextView: UITextView?
    @IBOutlet private var showUploadButton: UIButton?
    @IBOutlet private var uploadAsImagePickerInfoButton: UIButton?
    @IBOutlet private var uploadAsPHAssetButton: UIButton?
    @IBOutlet private var uploadAsUIImageButton: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        clientIDTextField?.text = clientID
        update()
    }
    
    private func update() {
        let hasClientID = clientID != ""
        let uploadInProgress = progress != nil && progress?.isFinished == false
        
        checkRateLimitButton?.isEnabled = hasClientID && !uploadInProgress
        
        imageButton?.isEnabled = !uploadInProgress
        let image = imagePickerInfo?[.editedImage] as? UIImage
            ?? imagePickerInfo?[.originalImage] as? UIImage
        imageButton?.setBackgroundImage(image, for: .normal)
        imageButton?.setTitle(image == nil ? "Choose Image" : nil, for: .normal)
        
        for button in [uploadAsImagePickerInfoButton, uploadAsPHAssetButton, uploadAsUIImageButton] {
            button?.isEnabled = hasClientID && imagePickerInfo != nil && !uploadInProgress
        }
        
        showUploadButton?.isEnabled = link != nil && !uploadInProgress
    }

    @IBAction private func didChangeClientID(_ sender: UITextField) {
        clientID = sender.text ?? ""
        UserDefaults.standard.imgurClientID = clientID
        uploader = nil
        update()
    }

    @IBAction private func didTapCheckRateLimits(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            beginOperation {
                uploader.checkRateLimitStatus {
                    self.endOperation($0)
                }
            }
        } catch {
            alert(error)
        }
    }

    @IBAction private func didTapImage(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @IBAction func didTapRequestPhotoAuth(_ sender: Any) {
        PHPhotoLibrary.requestAuthorization { status in
            print("photo authorization status is \(status.rawValue)")
        }
    }
    
    @IBAction private func didTapShowUpload(_ sender: Any) {
        guard let link = link else {
            return alert(MissingLink())
        }
        
        let safari = SFSafariViewController(url: link)
        present(safari, animated: true)
    }
    
    @IBAction private func didTapUploadAsPHAsset(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            let info = try obtainPHAsset()
            beginOperation {
                uploader.upload(info) {
                    self.endOperation($0)
                }
            }
        } catch {
            alert(error)
        }
    }

    @IBAction private func didTapUploadAsUIImage(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            let info = try obtainUIImage()
            beginOperation {
                uploader.upload(info) {
                    self.endOperation($0)
                }
            }
        } catch {
            alert(error)
        }
    }

    @IBAction private func didTapUploadAsWhatever(_ sender: Any) {
        do {
            let uploader = try obtainUploader()
            let info = try obtainImagePickerInfo()
            beginOperation {
                uploader.upload(info) {
                    self.endOperation($0)
                }
            }
        } catch {
            alert(error)
        }
    }

    private func beginOperation(_ starter: () -> Progress) {
        view.endEditing(true)
        progress = starter()
        update()
    }
    
    private func endOperation(_ result: ImgurUploader.Result<ImgurUploader.UploadResponse>) {
        switch result {
        case .success(let value):
            resultsTextView?.text = "hooray!\n\(value)"
            link = value.link
            
        case .failure(let error):
            resultsTextView?.text = "boo!\n\(error)"
            alert(error)
        }
        update()
    }

    private func endOperation<T>(_ result: ImgurUploader.Result<T>) {
        switch result {
        case .success(let value):
            resultsTextView?.text = "hooray!\n\(value)"
        case .failure(let error):
            resultsTextView?.text = "boo!\n\(error)"
            alert(error)
        }
        update()
    }

    private func alert(_ error: Error) {
        let title: String
        let message: String
        switch error {
        case let error as LocalizedError:
            title = error.errorDescription ?? "Error"
            message = error.failureReason ?? "\(error)"
        default:
            title = "Error"
            message = "\(error)"
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func obtainUploader() throws -> ImgurUploader {
        if let uploader = self.uploader {
            return uploader
        }

        guard !clientID.isEmpty else {
            throw MissingClientID()
        }

        let uploader = ImgurUploader(clientID: clientID)
        self.uploader = uploader
        return uploader
    }

    private func obtainImagePickerInfo() throws -> [UIImagePickerController.InfoKey: Any] {
        if let info = imagePickerInfo {
            return info
        } else {
            throw MissingImage()
        }
    }

    private func obtainPHAsset() throws -> PHAsset {
        if #available(iOS 11.0, *), let asset = imagePickerInfo?[.phAsset] as? PHAsset {
            return asset
        } else {
            throw MissingImage()
        }
    }

    private func obtainUIImage() throws -> UIImage {
        if let image = imagePickerInfo?[.editedImage] as? UIImage {
            return image
        } else if let image = imagePickerInfo?[.originalImage] as? UIImage {
            return image
        } else {
            throw MissingImage()
        }
    }
}

struct MissingClientID: Error {}
struct MissingImage: Error {}
struct MissingLink: Error {}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        imagePickerInfo = info
        update()

        dismiss(animated: true)
    }
}

private extension UserDefaults {
    @objc var imgurClientID: String? {
        get { return string(forKey: #function) }
        set { set(newValue, forKey: #function) }
    }
}
