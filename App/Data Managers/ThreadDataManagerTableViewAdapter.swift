//  ThreadDataManagerTableViewAdapter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

final class ThreadDataManagerTableViewAdapter: NSObject, UITableViewDataSource, ThreadDataManagerDelegate {
    private let tableView: UITableView
    private let dataManager: ThreadDataManager
    private let ignoreSticky: Bool
    private let cellConfigurationHandler: (ThreadTableViewCell, ThreadTableViewCell.ViewModel) -> Void
    private var viewModels: [ThreadTableViewCell.ViewModel]
    var deletionHandler: (Thread -> Void)?
    
    init(tableView: UITableView, dataManager: ThreadDataManager, ignoreSticky: Bool, cellConfigurationHandler: (ThreadTableViewCell, ThreadTableViewCell.ViewModel) -> Void) {
        self.tableView = tableView
        self.dataManager = dataManager
        self.ignoreSticky = ignoreSticky
        self.cellConfigurationHandler = cellConfigurationHandler
        viewModels = []
        super.init()
        
        viewModels = dataManager.threads.map(createViewModel)
    }
    
    private func createViewModel(thread: Thread) -> ThreadTableViewCell.ViewModel {
        return ThreadTableViewCell.ViewModel(thread: thread, showsTag: AwfulSettings.sharedSettings().showThreadTags, ignoreSticky: ignoreSticky)
    }
    
    // MARK: ThreadDataManagerDelegate
    
    func dataManagerDidChangeContent(dataManager: ThreadDataManager) {
        let oldViewModels = viewModels
        viewModels = dataManager.threads.map(createViewModel)
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
        let thread = dataManager.threads[indexPath.row]
        deletionHandler!(thread)
    }
}

private extension ThreadTableViewCell.ViewModel {
    init(thread: Thread, showsTag: Bool, ignoreSticky: Bool) {
        title = thread.title ?? ""
        numberOfPages = Int(thread.numberOfPages)
        
        if thread.beenSeen {
            let poster = thread.lastPostAuthorName ?? ""
            killedPostedBy = "Killed by \(poster)"
            unreadPosts = Int(thread.unreadPosts)
        } else {
            let author = thread.author?.username ?? ""
            killedPostedBy = "Posted by \(author)"
            unreadPosts = 0
        }
        
        starCategory = thread.starCategory
        
        showsTagAndRating = showsTag
        if let
            imageName = thread.threadTag?.imageName,
            image = AwfulThreadTagLoader.imageNamed(imageName)
        {
            tag = image
            tagImageName = imageName
        } else {
            tag = AwfulThreadTagLoader.emptyThreadTagImage()
            tagImageName = AwfulThreadTagLoaderEmptyThreadTagImageName
        }
        
        if let secondaryTagImageName = thread.secondaryThreadTag?.imageName {
            secondaryTag = UIImage(named: secondaryTagImageName)
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
