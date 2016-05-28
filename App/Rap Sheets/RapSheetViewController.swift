//  RapSheetViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// Displays a list of probations and bans.
final class RapSheetViewController: TableViewController {
    private let user: User?
    private let punishments = NSMutableOrderedSet()
    private var mostRecentlyLoadedPage = 0
    private lazy var doneItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(didTapDone))
    }()
    private lazy var banDateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        return formatter
    }()

    
    init(user: User?) {
        self.user = user
        super.init(style: .Plain)
        
        if user == nil {
            title = "Leper's Colony"
            tabBarItem.title = "Lepers"
            tabBarItem.image = UIImage(named: "lepers")
            tabBarItem.selectedImage = UIImage(named: "lepers-filled")
        } else {
            title = "Rap Sheet"
            hidesBottomBarWhenPushed = true
            modalPresentationStyle = .FormSheet
        }
    }
    
    convenience init() {
        self.init(user: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func load(page page: Int) {
        AwfulForumsClient.sharedClient().listPunishmentsOnPage(page, forUser: user) { [weak self] (error, newPunishments) in
            if let error = error {
                self?.presentViewController(UIAlertController.alertWithNetworkError(error), animated: true, completion: nil)
                return
            }
            
            self?.mostRecentlyLoadedPage = page
            
            if page == 1 {
                self?.punishments.removeAllObjects()
                self?.punishments.addObjectsFromArray(newPunishments)
                self?.tableView.reloadData()
                
                if self?.punishments.count == 0 {
                    self?.showNothingToSeeView()
                } else {
                    self?.setUpInfiniteScroll()
                }
            } else {
                let oldCount = self?.punishments.count ?? 0
                if newPunishments != nil {
                    self?.punishments.addObjectsFromArray(newPunishments)
                }
                let newCount = self?.punishments.count ?? 0
                let indexPaths = (oldCount..<newCount).map { NSIndexPath(forRow: $0, inSection: 0) }
                self?.tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
            }
            
            self?.refreshControl?.endRefreshing()
            self?.infiniteScrollController?.stop()
        }
    }
    
    private func showNothingToSeeView() {
        let label = UILabel()
        label.text = "Nothing to see here…"
        label.frame = CGRect(origin: .zero, size: view.bounds.size)
        label.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        label.textAlignment = .Center
        label.textColor = theme["listTextColor"]
        view.addSubview(label)
    }
    
    private func setUpInfiniteScroll() {
        scrollToLoadMoreBlock = { [weak self] in
            guard let latestPage = self?.mostRecentlyLoadedPage else { return }
            self?.load(page: latestPage + 1)
        }
    }
    
    @objc private func didTapDone() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    private func refreshIfNecessary() {
        guard punishments.count == 0 else { return }
        refresh()
    }
    
    @objc private func refresh() {
        refreshControl?.beginRefreshing()
        load(page: 1)
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerClass(PunishmentCell.self, forCellReuseIdentifier: cellID)
        tableView.separatorStyle = .None
        tableView.hideExtraneousSeparators()
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), forControlEvents: .ValueChanged)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        guard presentingViewController != nil && navigationController?.viewControllers.count == 1 else { return }
        navigationItem.rightBarButtonItem = doneItem
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        refreshIfNecessary()
    }
    
    // MARK: - UITableViewDataSource and UITableViewDelegate
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return punishments.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellID, forIndexPath: indexPath) as! PunishmentCell
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
        let date = banDateFormatter.stringFromDate(punishment.date)
        cell.detailTextLabel?.text = "\(date) by \(punishment.requester?.username ?? "")"
        cell.reasonLabel.text = punishment.reasonHTML
        
        let description: String
        switch punishment.sentence {
        case .Probation: description = "probated"
        case .Permaban: description = "permabanned"
        default: description = "banned"
        }
        cell.accessibilityLabel = "\(punishment.subject.username) was \(description) by \(punishment.requester?.username ?? "") on \(date): \(punishment.reasonHTML ?? "")"
        
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.detailTextLabel?.textColor = theme["listSecondaryTextColor"]
        cell.reasonLabel.textColor = theme["listTextColor"]
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = theme["listSelectedBackgroundColor"]
        
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let punishment = punishments[indexPath.row] as! Punishment
        return PunishmentCell.rowHeightWithBanReason(punishment.reasonHTML ?? "", width: tableView.bounds.width)
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let punishment = punishments[indexPath.row] as! Punishment
        guard punishment.post?.postID.isEmpty == false else { return }
        guard let
            postID = punishment.post?.postID,
            URL = NSURL(string: "awful://posts/\(postID)")
            else { return }
        AppDelegate.instance.openAwfulURL(URL)
        if presentingViewController != nil {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
}

private let cellID = "Cell"
