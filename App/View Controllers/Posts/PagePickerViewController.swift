import UIKit
import AwfulCore

/// Temporary stub replacement for the old `PagePickerViewController` that was removed as part of the SwiftUI migration.
/// It simply presents a `UIPickerView` wrapped in a view controller, allowing callers to choose a page number.
/// When you have time, swap this out for the proper SwiftUI-based picker everywhere and remove this file.
final class PagePickerViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    // MARK: - Public API

    /// Creates a page picker pre-selected to the supplied page number.
    /// - Parameters:
    ///   - page:          The current page as a 1-based index.
    ///   - numberOfPages: Total number of pages available.
    ///   - completion:    Called when the user taps Done, passing the selected page.
    static func make(page: ThreadPage, numberOfPages: Int, completion: @escaping (ThreadPage) -> Void) -> UIViewController {
        let vc = PagePickerViewController(currentPage: page, numberOfPages: numberOfPages, completion: completion)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        return nav
    }

    // MARK: - Private

    private let currentPage: ThreadPage
    private let numberOfPages: Int
    private let completion: (ThreadPage) -> Void

    private lazy var pickerView = UIPickerView()

    private init(currentPage: ThreadPage, numberOfPages: Int, completion: @escaping (ThreadPage) -> Void) {
        self.currentPage = currentPage
        self.numberOfPages = numberOfPages
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Jump to page"
        view.backgroundColor = .systemBackground

        pickerView.dataSource = self
        pickerView.delegate = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pickerView)

        NSLayoutConstraint.activate([
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pickerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pickerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        if case .specific(let pageNumber) = currentPage {
            pickerView.selectRow(pageNumber - 1, inComponent: 0, animated: false)
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
    }

    @objc private func didTapDone() {
        let selectedRow = pickerView.selectedRow(inComponent: 0)
        completion(.specific(selectedRow + 1))
        dismiss(animated: true)
    }

    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        numberOfPages
    }

    // MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        "\(row + 1) / \(numberOfPages)"
    }
} 