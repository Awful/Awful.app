//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

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
            title = LocalizedString("lepers-colony.navbar-title")
            tabBarItem.title = LocalizedString("lepers-colony.tabbar-title")
            tabBarItem.image = UIImage(named: "lepers")
            tabBarItem.selectedImage = UIImage(named: "lepers-filled")
        } else {
            title = LocalizedString("rap-sheet.title")
            hidesBottomBarWhenPushed = true
            modalPresentationStyle = .formSheet
        }
    }
    
    private func load(_ page: Int) {
        _ = ForumsClient.shared.listPunishments(of: user, page: page)
            .done { [weak self] newPunishments in
                guard let self = self else { return }

                self.mostRecentlyLoadedPage = page

                if page == 1 {
                    self.punishments.removeAllObjects()
                    self.punishments.addObjects(from: newPunishments)
                    self.tableView.reloadData()

                    if self.punishments.count == 0 {
                        self.showNothingToSeeView()
                    } else {
                        self.enableLoadMore()
                    }
                } else {
                    let oldCount = self.punishments.count
                    self.punishments.addObjects(from: newPunishments)
                    let newCount = self.punishments.count
                    let indexPaths = (oldCount..<newCount).map { IndexPath(row: $0, section: 0) }
                    self.tableView.insertRows(at: indexPaths, with: .automatic)
                }
            }
            .catch { [weak self] error in
                self?.present(UIAlertController(networkError: error), animated: true)
            }
            .finally { [weak self] in
                guard let self = self else { return }
                
                self.stopAnimatingPullToRefresh()
                self.loadMoreFooter?.didFinish()
        }
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
            guard let self = self else { return }
            
            self.load(self.mostRecentlyLoadedPage + 1)
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
        load(1)
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
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        return PunishmentCell.rowHeightWithBanReason(punishment.reason, width: tableView.safeAreaFrame.width)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let punishment = punishments[indexPath.row] as! LepersColonyScrapeResult.Punishment
        guard let postID = punishment.post?.rawValue else { return }

        AppDelegate.instance.open(route: .post(id: postID))

        if presentingViewController != nil {
            dismiss(animated: true)
        }
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let cellID = "Cell"
