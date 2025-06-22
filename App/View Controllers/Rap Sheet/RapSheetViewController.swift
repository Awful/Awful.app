//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import ScrollViewDelegateMultiplexer
import UIKit

extension Notification.Name {
    static let route = Notification.Name("AwfulRoute")
}

/// Displays a list of probations and bans.
final class RapSheetViewController: TableViewController {
    
    private var loadMoreFooter: LoadMoreFooter?
    private var mostRecentlyLoadedPage = 0
    private let punishments = NSMutableOrderedSet()
    private let user: User?
    
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
        ScrollViewDelegateMultiplexer(scrollView: tableView)
    }()
    
    init(user: User? = nil) {
        self.user = user
        super.init(style: .plain)
        
        if user == nil {
            title = String(localized: "Leper's Colony", bundle: .module)
            // Tab bar item title is set in `themeDidChange()` as some themes do not show titles.
            tabBarItem.image = UIImage(named: "lepers")
            tabBarItem.selectedImage = UIImage(named: "lepers-filled")
        } else {
            title = String(localized: "Rap Sheet", bundle: .module)
            hidesBottomBarWhenPushed = true
            modalPresentationStyle = .formSheet
        }
        
        themeDidChange()
    }
    
    private func load(_ page: Int) async {
        do {
            let newPunishments = try await ForumsClient.shared.listPunishments(of: user, page: page)
            mostRecentlyLoadedPage = page

            if page == 1 {
                punishments.removeAllObjects()
                punishments.addObjects(from: newPunishments)
                tableView.reloadData()

                if punishments.count == 0 {
                    showNothingToSeeView()
                } else {
                    enableLoadMore()
                }
            } else {
                let oldCount = punishments.count
                punishments.addObjects(from: newPunishments)
                let newCount = punishments.count
                let indexPaths = (oldCount..<newCount).map { IndexPath(row: $0, section: 0) }
                tableView.insertRows(at: indexPaths, with: .automatic)
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
        
        loadMoreFooter = LoadMoreFooter(tableView: tableView, multiplexer: multiplexer, loadMore: { [weak self] loadMoreFooter in
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
        
        tableView.register(PunishmentCell.self, forCellReuseIdentifier: cellID)
        tableView.separatorStyle = .none
        tableView.hideExtraneousSeparators()
        
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
    
    // MARK: - UITableViewDataSource and UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return punishments.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as! PunishmentCell
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        
        switch punishment.sentence {
        case .probation?:
            cell.imageView?.image = UIImage(named: "title-probation")
            
        case .permaban?:
            cell.imageView?.image = UIImage(named: "title-permabanned.gif")
            
        case .ban?, .autoban?:
            cell.imageView?.image = UIImage(named: "title-banned.gif")
            
        case .none:
            cell.imageView?.image = nil
        }
        
        cell.textLabel?.text = punishment.subjectUsername

        let formattedDate = punishment.date.map(banDateFormatter.string)
        cell.detailTextLabel?.text = {
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
        
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.detailTextLabel?.textColor = theme["listSecondaryTextColor"]
        cell.reasonLabel.textColor = theme["listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        let tableWidth = tableView.safeAreaLayoutGuide.layoutFrame.width
        return PunishmentCell.rowHeightWithBanReason(formatReason(punishment.reasonAttributed), width: tableWidth)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        guard let postID = punishment.post?.rawValue else { return }

        NotificationCenter.default.post(name: .route, object: AwfulRoute.post(id: postID, .noseen))

        if presentingViewController != nil {
            dismiss(animated: true)
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        tableView.separatorColor = theme["listSeparatorColor"]
        
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func formatReason(_ reason: NSAttributedString) -> NSAttributedString {
        let mutableReason = NSMutableAttributedString(attributedString: reason)
        
        /// Resize any images in punishment reasons so they fit on the screen
        mutableReason.enumerateAttribute(NSAttributedString.Key.attachment, in: NSMakeRange(0, mutableReason.length), options: .init(rawValue: 0), using: { (value, range, stop) in
            if let attachement = value as? NSTextAttachment {
                let tableWidth = tableView.safeAreaLayoutGuide.layoutFrame.width
                let maxWidth = tableWidth - PunishmentCell.reasonInsets.left - PunishmentCell.reasonInsets.right
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

private let cellID = "Cell"
