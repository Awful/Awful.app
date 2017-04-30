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
        _ = ForumsClient.shared.listPunishments(of: user, page: page) { [weak self] (error: Error?, newPunishments: [Punishment]?) in
            if let error = error {
                self?.present(UIAlertController.alertWithNetworkError(error), animated: true, completion: nil)
                return
            }
            
            let newPunishments = newPunishments ?? []
            
            self?.mostRecentlyLoadedPage = page
            
            if page == 1 {
                self?.punishments.removeAllObjects()
                self?.punishments.addObjects(from: newPunishments)
                self?.tableView.reloadData()
                
                if self?.punishments.count == 0 {
                    self?.showNothingToSeeView()
                } else {
                    self?.setUpInfiniteScroll()
                }
            } else {
                let oldCount = self?.punishments.count ?? 0
                self?.punishments.addObjects(from: newPunishments)
                let newCount = self?.punishments.count ?? 0
                let indexPaths = (oldCount..<newCount).map { IndexPath(row: $0, section: 0) }
                self?.tableView.insertRows(at: indexPaths, with: .automatic)
            }
            
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
        let punishment = punishments[indexPath.row] as! Punishment
        
        switch punishment.sentence {
        case .Probation:
            cell.imageView?.image = UIImage(named: "title-probation")
            
        case .Permaban:
            cell.imageView?.image = UIImage(named: "title-permabanned.gif")
            
        case .Ban, .Autoban:
            cell.imageView?.image = UIImage(named: "title-banned.gif")
            
        case .Unknown:
            cell.imageView?.image = nil
        }
        
        cell.textLabel?.text = punishment.subject.username
        let date = banDateFormatter.string(from: punishment.date as Date)
        cell.detailTextLabel?.text = "\(date) by \(punishment.requester?.username ?? "")"
        cell.reasonLabel.text = punishment.reasonHTML
        
        let description: String
        switch punishment.sentence {
        case .Probation: description = "probated"
        case .Permaban: description = "permabanned"
        default: description = "banned"
        }
        cell.accessibilityLabel = "\(String(describing: punishment.subject.username)) was \(description) by \(punishment.requester?.username ?? "") on \(date): \(punishment.reasonHTML ?? "")"
        
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.detailTextLabel?.textColor = theme["listSecondaryTextColor"]
        cell.reasonLabel.textColor = theme["listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let punishment = punishments[indexPath.row] as! Punishment
        return PunishmentCell.rowHeightWithBanReason(punishment.reasonHTML ?? "", width: tableView.bounds.width)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let punishment = punishments[indexPath.row] as! Punishment
        guard punishment.post?.postID.isEmpty == false else { return }
        guard let
            postID = punishment.post?.postID,
            let URL = URL(string: "awful://posts/\(postID)")
            else { return }
        AppDelegate.instance.openAwfulURL(URL)
        if presentingViewController != nil {
            dismiss(animated: true, completion: nil)
        }
    }
}

private let cellID = "Cell"
