//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// Displays a list of probations and bans.
final class RapSheetViewController: TableViewController {
    fileprivate let user: User?
    fileprivate let punishments = NSMutableOrderedSet()
    fileprivate var mostRecentlyLoadedPage = 0
    fileprivate lazy var doneItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
    }()
    fileprivate lazy var banDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    
    init(user: User?) {
        self.user = user
        super.init(style: .plain)
        
        if user == nil {
            title = "Leper's Colony"
            tabBarItem.title = "Lepers"
            tabBarItem.image = UIImage(named: "lepers")
            tabBarItem.selectedImage = UIImage(named: "lepers-filled")
        } else {
            title = "Rap Sheet"
            hidesBottomBarWhenPushed = true
            modalPresentationStyle = .formSheet
        }
    }
    
    convenience init() {
        self.init(user: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func load(_ page: Int) {
        _ = ForumsClient.shared.listPunishments(of: user, page: page)
            .then { [weak self]  (newPunishments) -> Void in
                guard let sself = self else { return }

                sself.mostRecentlyLoadedPage = page

                if page == 1 {
                    sself.punishments.removeAllObjects()
                    sself.punishments.addObjects(from: newPunishments)
                    sself.tableView.reloadData()

                    if sself.punishments.count == 0 {
                        sself.showNothingToSeeView()
                    } else {
                        sself.setUpInfiniteScroll()
                    }
                } else {
                    let oldCount = sself.punishments.count
                    sself.punishments.addObjects(from: newPunishments)
                    let newCount = sself.punishments.count
                    let indexPaths = (oldCount..<newCount).map { IndexPath(row: $0, section: 0) }
                    sself.tableView.insertRows(at: indexPaths, with: .automatic)
                }
            }
            .catch { [weak self] (error) -> Void in
                self?.present(UIAlertController.alertWithNetworkError(error), animated: true)
            }
            .always { [weak self] in
                self?.stopAnimatingPullToRefresh()
                self?.stopAnimatingInfiniteScroll()
        }
    }
    
    fileprivate func showNothingToSeeView() {
        let label = UILabel()
        label.text = "Nothing to see here…"
        label.frame = CGRect(origin: .zero, size: view.bounds.size)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.textAlignment = .center
        label.textColor = theme["listTextColor"]
        view.addSubview(label)
    }
    
    fileprivate func setUpInfiniteScroll() {
        scrollToLoadMoreBlock = { [weak self] in
            guard let latestPage = self?.mostRecentlyLoadedPage else { return }
            self?.load(latestPage + 1)
        }
    }
    
    @objc fileprivate func didTapDone() {
        dismiss(animated: true, completion: nil)
    }
    
    fileprivate func refreshIfNecessary() {
        guard punishments.count == 0 else { return }
        refresh()
    }
    
    @objc fileprivate func refresh() {
        startAnimatingPullToRefresh()
        load(1)
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        cell.reasonLabel.text = punishment.reason
        
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
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        return PunishmentCell.rowHeightWithBanReason(punishment.reason, width: tableView.bounds.width)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        guard
            let postID = punishment.post?.rawValue,
            let url = URL(string: "awful://posts/\(postID)")
            else { return }
        AppDelegate.instance.openAwfulURL(url)
        if presentingViewController != nil {
            dismiss(animated: true, completion: nil)
        }
    }
}

private let cellID = "Cell"
