//  ThreadDataManagerTableViewAdapter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

final class ThreadDataManagerTableViewAdapter: NSObject, UITableViewDataSource, FetchedDataManagerDelegate {
    typealias DataManager = FetchedDataManager<Thread>
    
    private let tableView: UITableView
    private let dataManager: DataManager
    private let ignoreSticky: Bool
    private let cellConfigurationHandler: (ThreadTableViewCell, ThreadTableViewCell.ViewModel) -> Void
    private var viewModels: [ThreadTableViewCell.ViewModel]
    var deletionHandler: (Thread -> Void)?
    
    init(tableView: UITableView, dataManager: DataManager, ignoreSticky: Bool, cellConfigurationHandler: (ThreadTableViewCell, ThreadTableViewCell.ViewModel) -> Void) {
        self.tableView = tableView
        self.dataManager = dataManager
        self.ignoreSticky = ignoreSticky
        self.cellConfigurationHandler = cellConfigurationHandler
        viewModels = []
        super.init()
        
        viewModels = dataManager.contents.map(createViewModel)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ThreadDataManagerTableViewAdapter.threadTagDidDownload(_:)), name: AwfulThreadTagLoaderNewImageAvailableNotification, object: AwfulThreadTagLoader.sharedLoader())
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    private func createViewModel(thread: Thread) -> ThreadTableViewCell.ViewModel {
        return ThreadTableViewCell.ViewModel(thread: thread, showsTag: AwfulSettings.sharedSettings().showThreadTags, ignoreSticky: ignoreSticky)
    }
    
    private func reloadViewModels() {
        let oldViewModels = viewModels
        viewModels = dataManager.contents.map(createViewModel)
        let delta = oldViewModels.delta(viewModels)
        guard !delta.isEmpty else { return }
        
        tableView.beginUpdates()
        
        func pathify(row: Int) -> NSIndexPath {
            return NSIndexPath(forRow: row, inSection: 0)
        }
        
        let deletions = delta.deletions.map(pathify)
        tableView.deleteRowsAtIndexPaths(deletions, withRowAnimation: .Automatic)
        
        let insertions = delta.insertions.map(pathify)
        tableView.insertRowsAtIndexPaths(insertions, withRowAnimation: .Automatic)
        
        for (fromRow, toRow) in delta.moves {
            tableView.moveRowAtIndexPath(pathify(fromRow), toIndexPath: pathify(toRow))
        }
        
        tableView.endUpdates()
    }
    
    // MARK: Notifications
    
    @objc private func threadTagDidDownload(notification: NSNotification) {
        guard let newImageName = notification.userInfo?[AwfulThreadTagLoaderNewImageNameKey] as? String else {
            return
        }
        
        let shouldReload = viewModels.contains { viewModel in
            switch viewModel.tag {
            case let .Unavailable(_, desiredImageName: imageName) where imageName == newImageName:
                return true
                
            default:
                return false
            }
        }
        
        if shouldReload {
            reloadViewModels()
        }
    }
    
    // MARK: FetchedDataManagerDelegate
    
    func dataManagerDidChangeContent<Object>(dataManager: FetchedDataManager<Object>) {
        reloadViewModels()
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ThreadTableViewCell.identifier, forIndexPath: indexPath) as! ThreadTableViewCell
        let viewModel = viewModels[indexPath.row]
        cellConfigurationHandler(cell, viewModel)
        return cell
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return deletionHandler != nil
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        let thread = dataManager.contents[indexPath.row]
        deletionHandler!(thread)
    }
}

private extension ThreadTableViewCell.ViewModel {
    init(thread: Thread, showsTag: Bool, ignoreSticky: Bool) {
        title = thread.title ?? ""
        numberOfPages = Int(thread.numberOfPages)
        
        beenSeen = thread.beenSeen
        killedBy = thread.lastPostAuthorName ?? ""
        postedBy = thread.author?.username ?? ""
        
        unreadPosts = Int(thread.unreadPosts)
        starCategory = thread.starCategory
        
        showsTagAndRating = showsTag
        let imageName = thread.threadTag?.imageName
        if let
            imageName = imageName,
            image = AwfulThreadTagLoader.imageNamed(imageName)
        {
            tag = Tag.Downloaded(image)
        } else {
            let image = AwfulThreadTagLoader.emptyThreadTagImage()
            tag = .Unavailable(fallbackImage: image, desiredImageName: imageName ?? "")
        }
        
        if let secondaryTagImageName = thread.secondaryThreadTag?.imageName {
            secondaryTag = AwfulThreadTagLoader.imageNamed(secondaryTagImageName)
            self.secondaryTagImageName = secondaryTagImageName
        } else {
            secondaryTag = nil
            secondaryTagImageName = nil
        }
        
        var rating: Int?
        if AwfulForumTweaks(forumID: thread.forum?.forumID)?.showRatings ?? true {
            let rounded = lroundf(thread.rating).clamp(0...5)
            if rounded != 0 {
                rating = rounded
            }
        }
        if let rating = rating {
            let imageName = "rating\(rating)"
            self.rating = UIImage(named: imageName)
            ratingImageName = imageName
        } else {
            self.rating = nil
            ratingImageName = nil
        }
        
        let faded = thread.closed && !thread.sticky
        let alpha: CGFloat = faded ? 0.5 : 1
        titleAlpha = alpha
        tagAndRatingAlpha = alpha
        
        self.sticky = ignoreSticky ? false : thread.sticky
    }
}
