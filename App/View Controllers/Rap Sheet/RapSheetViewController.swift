//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import ScrollViewDelegateMultiplexer
import UIKit

/// Displays a list of probations and bans.
final class RapSheetViewController: CollectionViewController {

    private var loadMoreFooter: LoadMoreCollectionFooter?
    private var mostRecentlyLoadedPage = 0
    private let punishments = NSMutableOrderedSet()
    private let user: User?
    private var cellRegistration: UICollectionView.CellRegistration<PunishmentCell, LepersColonyScrapeResult.Punishment>!

    private lazy var banDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var doneItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
    }()

    private lazy var multiplexer: ScrollViewDelegateMultiplexer = {
        ScrollViewDelegateMultiplexer(scrollView: collectionView)
    }()

    init(user: User? = nil) {
        self.user = user
        super.init(collectionViewLayout: Self.makeLayout())

        if user == nil {
            title = String(localized: "Leper’s Colony", bundle: .module)
            // Tab bar item title is set in `themeDidChange()` as some themes do not show titles.
            tabBarItem.image = UIImage(named: "lepers")
            tabBarItem.selectedImage = UIImage(named: "lepers-filled")
        } else {
            title = String(localized: "Rap Sheet", bundle: .module)
            hidesBottomBarWhenPushed = true
            modalPresentationStyle = .formSheet
        }

        cellRegistration = makeCellRegistration()

        themeDidChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        return CollectionViewController.makeListLayout(using: config)
    }

    private func makeCellRegistration() -> UICollectionView.CellRegistration<PunishmentCell, LepersColonyScrapeResult.Punishment> {
        UICollectionView.CellRegistration<PunishmentCell, LepersColonyScrapeResult.Punishment> { [weak self] cell, _, punishment in
            guard let self else { return }
            self.configure(cell: cell, with: punishment)
        }
    }

    private func configure(cell: PunishmentCell, with punishment: LepersColonyScrapeResult.Punishment) {
        switch punishment.sentence {
        case .probation?:
            cell.iconView.image = UIImage(named: "title-probation")
        case .permaban?:
            cell.iconView.image = UIImage(named: "title-permabanned.gif")
        case .ban?, .autoban?:
            cell.iconView.image = UIImage(named: "title-banned.gif")
        case .none:
            cell.iconView.image = nil
        }

        cell.titleLabel.text = punishment.subjectUsername

        let formattedDate = punishment.date.map(banDateFormatter.string)
        cell.subtitleLabel.text = {
            var components: [String] = []
            if let formattedDate = formattedDate {
                components.append(formattedDate)
            }
            if !punishment.requesterUsername.isEmpty {
                components.append("by \(punishment.requesterUsername)")
            }
            return components.joined(separator: " ")
        }()

        cell.reasonLabel.attributedText = formatReason(punishment.reasonAttributed)

        let description: String
        switch punishment.sentence {
        case .probation?:
            description = "probated"
        case .permaban?:
            description = "permabanned"
        case .autoban?, .ban?, .none:
            description = "banned"
        }

        cell.accessibilityLabel = {
            var components: [String] = []
            if !punishment.subjectUsername.isEmpty {
                components.append(punishment.subjectUsername)
            }
            components.append("was \(description)")
            if !punishment.requesterUsername.isEmpty {
                components.append("by \(punishment.requesterUsername)")
            }
            if let formattedDate = formattedDate {
                components.append("on \(formattedDate)")
            }
            components.append(":")
            components.append(punishment.reason)
            return components.joined(separator: " ")
        }()

        cell.titleLabel.textColor = theme["listTextColor"]
        cell.subtitleLabel.textColor = theme["listSecondaryTextColor"]
        cell.reasonLabel.textColor = theme["listTextColor"]
        cell.bubbleColor = theme["listBackgroundColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
    }

    private func load(_ page: Int) async {
        do {
            let newPunishments = try await ForumsClient.shared.listPunishments(of: user, page: page)
            mostRecentlyLoadedPage = page

            if page == 1 {
                punishments.removeAllObjects()
                punishments.addObjects(from: newPunishments)
                collectionView.reloadData()

                if punishments.count == 0 {
                    showNothingToSeeView()
                } else {
                    enableLoadMore()
                }
            } else {
                let oldCount = punishments.count
                punishments.addObjects(from: newPunishments)
                let newCount = punishments.count
                let indexPaths = (oldCount..<newCount).map { IndexPath(item: $0, section: 0) }
                collectionView.insertItems(at: indexPaths)
            }
        } catch {
            present(UIAlertController(networkError: error), animated: true)
        }

        stopAnimatingPullToRefresh()
        loadMoreFooter?.didFinish()
    }

    private func showNothingToSeeView() {
        let label = UILabel()
        label.text = LocalizedString("rap-sheet.empty")
        label.frame = CGRect(origin: .zero, size: view.bounds.size)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.textAlignment = .center
        label.textColor = theme["listTextColor"]
        view.addSubview(label)
    }

    private func enableLoadMore() {
        guard loadMoreFooter == nil else { return }

        loadMoreFooter = LoadMoreCollectionFooter(collectionView: collectionView, multiplexer: multiplexer, loadMore: { [weak self] _ in
            guard let self else { return }
            Task { await self.load(self.mostRecentlyLoadedPage + 1) }
        })
    }

    @objc private func didTapDone() {
        dismiss(animated: true, completion: nil)
    }

    private func refreshIfNecessary() {
        guard punishments.count == 0 else { return }
        refresh()
    }

    @objc private func refresh() {
        startAnimatingPullToRefresh()
        Task { await load(1) }
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        multiplexer.addDelegate(self)

        pullToRefreshBlock = { [unowned self] in
            self.refresh()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard presentingViewController != nil && navigationController?.viewControllers.count == 1 else { return }
        navigationItem.rightBarButtonItem = doneItem
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        refreshIfNecessary()
    }

    // MARK: - UICollectionViewDataSource and UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return punishments.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let punishment = punishments[indexPath.item] as! LepersColonyScrapeResult.Punishment
        return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: punishment)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let punishment = punishments[indexPath.item] as! LepersColonyScrapeResult.Punishment
        guard let postID = punishment.post?.rawValue else { return }

        AppDelegate.instance.open(route: .post(id: postID, .noseen))

        if presentingViewController != nil {
            dismiss(animated: true)
        }
    }

    override func themeDidChange() {
        super.themeDidChange()

        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = if user == nil {
                String(localized: "Lepers", bundle: .module)
            } else {
                String(localized: "Rap Sheet", bundle: .module)
            }
        }
    }

    // MARK: Gunk

    func formatReason(_ reason: NSAttributedString) -> NSAttributedString {
        let mutableReason = NSMutableAttributedString(attributedString: reason)

        /// Resize any images in punishment reasons so they fit on the screen
        mutableReason.enumerateAttribute(NSAttributedString.Key.attachment, in: NSMakeRange(0, mutableReason.length), options: .init(rawValue: 0), using: { (value, range, stop) in
            if let attachement = value as? NSTextAttachment {
                let collectionWidth = collectionView.safeAreaLayoutGuide.layoutFrame.width
                let maxWidth = collectionWidth - PunishmentCell.reasonInsets.left - PunishmentCell.reasonInsets.right
                let image = attachement.image(forBounds: attachement.bounds, textContainer: NSTextContainer(), characterIndex: range.location)!
                if image.size.width > maxWidth {
                    let scale = maxWidth/image.size.width
                    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let rect = CGRect(origin: CGPoint.zero, size: newSize)

                    UIGraphicsBeginImageContext(newSize)
                    image.draw(in: rect)
                    let newImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    let newAttribute = NSTextAttachment()
                    newAttribute.image = newImage
                    mutableReason.addAttribute(NSAttributedString.Key.attachment, value: newAttribute, range: range)
                }
            }
        })

        /// Set font color to theme color
        mutableReason.addAttribute(.foregroundColor, value: theme["listTextColor"]! as UIColor, range: NSMakeRange(0, reason.length))

        /// Set font size to cell's font size, overwrite the font size the HTML tries to set
        mutableReason.addAttribute(.font, value: PunishmentCell.reasonFont, range: NSMakeRange(0, mutableReason.length))

        return NSAttributedString(attributedString: mutableReason)
    }
}
