//  ReportPostViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import MRProgress

final class ReportPostViewController: ViewController, UITextViewDelegate {
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    fileprivate let post: Post
    private var maxCharacters: Int = 1000

    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)

        title = "Report Post"
        modalPresentationStyle = .formSheet

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .done, target: self, action: #selector(didTapSubmit))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBAction @objc fileprivate func didTapCancel() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        dismiss(animated: true, completion: nil)
    }

    @IBAction fileprivate func didTapSubmit() {
        if enableHaptics {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        rootView.endEditing(true)
        guard let text = rootView.commentTextView.text, !text.isEmpty else { return }

        let progressView = MRProgressOverlayView.showOverlayAdded(to: view.window, title: "Reporting…", mode: .indeterminate, animated: true)!
        Task {
            try? await ForumsClient.shared.report(post, nws: rootView.nwsSwitch.isOn, reason: text, maxCharacters: maxCharacters)
            progressView.dismiss(true)
            await dismiss(animated: true)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        let text = textView.text ?? ""
        navigationItem.rightBarButtonItem?.isEnabled = !text.isEmpty && text.count <= maxCharacters
    }

    fileprivate class RootView: UIView {
        let instructionLabel = UILabel()
        let nwsLabel = UILabel()
        let nwsSwitch = UISwitch()
        let commentFieldLabel = UILabel()
        let commentTextView = UITextView()
        let errorTextView = UITextView()

        var formElements: [UIView] {
            [nwsSwitch, nwsLabel, commentFieldLabel, commentTextView]
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            instructionLabel.numberOfLines = 0
            addSubview(instructionLabel)

            nwsLabel.numberOfLines = 0
            addSubview(nwsLabel)

            addSubview(nwsSwitch)

            commentFieldLabel.text = "Message:"
            commentFieldLabel.numberOfLines = 0
            addSubview(commentFieldLabel)

            commentTextView.font = commentFieldLabel.font
            commentTextView.layer.borderWidth = 1
            commentTextView.layer.cornerRadius = 4
            addSubview(commentTextView)

            errorTextView.isEditable = false
            errorTextView.isScrollEnabled = false
            errorTextView.backgroundColor = .clear
            errorTextView.textAlignment = .center
            errorTextView.isHidden = true
            addSubview(errorTextView)

            // Hide form elements until the report page is fetched
            for element in formElements {
                element.isHidden = true
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let safeArea = safeAreaInsets
            let availableArea = bounds.inset(by: UIEdgeInsets(
                top: safeArea.top + 8,
                left: safeArea.left + 8,
                bottom: safeArea.bottom + 8,
                right: safeArea.right + 8
            ))
            if !errorTextView.isHidden {
                let size = errorTextView.sizeThatFits(CGSize(width: availableArea.width, height: .greatestFiniteMagnitude))
                errorTextView.frame = CGRect(
                    x: availableArea.minX,
                    y: availableArea.minY,
                    width: availableArea.width,
                    height: size.height
                )
                return
            }

            instructionLabel.frame = availableArea
            instructionLabel.sizeToFit()

            guard !nwsSwitch.isHidden else { return }

            nwsSwitch.sizeToFit()
            nwsSwitch.frame.origin = CGPoint(x: availableArea.minX, y: instructionLabel.frame.maxY + 10)

            nwsLabel.frame = CGRect(
                x: nwsSwitch.frame.maxX + 8,
                y: nwsSwitch.frame.minY,
                width: availableArea.maxX - nwsSwitch.frame.maxX - 8,
                height: nwsSwitch.frame.height
            )

            commentFieldLabel.frame = availableArea
            commentFieldLabel.sizeToFit()
            commentFieldLabel.frame.origin.y = nwsSwitch.frame.maxY + 10

            commentTextView.frame = CGRect(
                x: availableArea.minX,
                y: commentFieldLabel.frame.maxY + 10,
                width: availableArea.width,
                height: max(120, (availableArea.maxY - commentFieldLabel.frame.maxY - 10) / 3)
            )
        }
    }

    fileprivate var rootView: RootView { return view as! RootView }

    override func loadView() {
        view = RootView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.commentTextView.delegate = self
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    private func fetchReportPage() {
        let progressView = MRProgressOverlayView.showOverlayAdded(to: view, title: "Loading…", mode: .indeterminate, animated: true)!

        Task {
            do {
                let formContents = try await ForumsClient.shared.fetchReportForm(for: post)
                progressView.dismiss(true)
                showForm(with: formContents)
            } catch {
                progressView.dismiss(true)
                showError(error)
            }
        }
    }

    private func showForm(with contents: ForumsClient.ReportFormContents) {
        maxCharacters = contents.maxCharacters
        rootView.instructionLabel.text = contents.instructionText
        rootView.nwsLabel.text = contents.nwsLabelText

        for element in rootView.formElements {
            element.isHidden = false
        }
        rootView.setNeedsLayout()
        rootView.commentTextView.becomeFirstResponder()
    }

    private static let dismissLinkURL = URL(string: "awful://dismiss")!

    private func showError(_ error: Swift.Error) {
        navigationItem.rightBarButtonItem = nil
        rootView.instructionLabel.isHidden = true

        let message = error.localizedDescription
        let textColor = theme[uicolor: "sheetTextColor"] ?? .label
        let attributed = NSMutableAttributedString(
            string: message,
            attributes: [
                .font: rootView.instructionLabel.font ?? UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: textColor,
            ]
        )

        // Make "Click here" a tappable link if present
        if let range = message.range(of: "Click here", options: .caseInsensitive) {
            let nsRange = NSRange(range, in: message)
            attributed.addAttribute(.link, value: Self.dismissLinkURL, range: nsRange)
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        attributed.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attributed.length))

        rootView.errorTextView.attributedText = attributed
        rootView.errorTextView.delegate = self
        rootView.errorTextView.isHidden = false
        rootView.setNeedsLayout()
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL == Self.dismissLinkURL {
            didTapCancel()
            return false
        }
        return true
    }

    override func themeDidChange() {
        super.themeDidChange()

        rootView.instructionLabel.textColor = theme["sheetTextColor"]
        rootView.nwsLabel.textColor = theme["sheetTextColor"]
        rootView.commentFieldLabel.textColor = theme["sheetTextColor"]
        rootView.commentTextView.textColor = theme["sheetTextColor"]
        rootView.commentTextView.backgroundColor = theme["sheetBackgroundColor"]
        rootView.commentTextView.layer.borderColor = theme[uicolor: "sheetTextAreaBorderColor"]?.cgColor
        rootView.nwsSwitch.onTintColor = theme["settingsSwitchColor"]
        rootView.errorTextView.linkTextAttributes = [.foregroundColor: theme[uicolor: "tintColor"] ?? .systemBlue]
    }

    private var didFetchReportPage = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didFetchReportPage else { return }
        didFetchReportPage = true
        fetchReportPage()
    }
}
