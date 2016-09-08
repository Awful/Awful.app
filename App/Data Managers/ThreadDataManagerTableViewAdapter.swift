//  ThreadDataManagerTableViewAdapter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

final class ThreadDataManagerTableViewAdapter: NSObject, UITableViewDataSource, FetchedDataManagerDelegate {
    typealias DataManager = FetchedDataManager<AwfulThread>
    
    private let tableView: UITableView
    private let dataManager: DataManager
    private let ignoreSticky: Bool
    private let cellConfigurationHandler: (ThreadTableViewCell, ThreadTableViewCell.ViewModel) -> Void
    private var viewModels: [ThreadTableViewCell.ViewModel]
    var deletionHandler: ((AwfulThread) -> Void)?
    
    init(tableView: UITableView, dataManager: DataManager, ignoreSticky: Bool, cellConfigurationHandler: @escaping (ThreadTableViewCell, ThreadTableViewCell.ViewModel) -> Void) {
        self.tableView = tableView
        self.dataManager = dataManager
        self.ignoreSticky = ignoreSticky
        self.cellConfigurationHandler = cellConfigurationHandler
        viewModels = []
        super.init()
        
        viewModels = dataManager.contents.map(createViewModel)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ThreadDataManagerTableViewAdapter.threadTagDidDownload(_:)), name: NSNotification.Name(rawValue: ThreadTagLoader.newImageAvailableNotification), object: ThreadTagLoader.sharedLoader)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func createViewModel(thread: AwfulThread) -> ThreadTableViewCell.ViewModel {
        return ThreadTableViewCell.ViewModel(thread: thread, showsTag: AwfulSettings.shared().showThreadTags, ignoreSticky: ignoreSticky)
    }
    
    private func reloadViewModels() {
        let oldViewModels = viewModels
        viewModels = dataManager.contents.map(createViewModel)
        let delta = oldViewModels.delta(viewModels)
        guard !delta.isEmpty else { return }
        
        tableView.beginUpdates()
        
        func pathify(row: Int) -> NSIndexPath {
            return NSIndexPath(row: row, section: 0)
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
    
    @objc private func threadTagDidDownload(_ notification: NSNotification) {
        guard let newImageName = notification.userInfo?[ThreadTagLoader.newImageNameKey] as? String else {
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThreadTableViewCell.identifier, for: indexPath as IndexPath) as! ThreadTableViewCell
        let viewModel = viewModels[indexPath.row]
        cellConfigurationHandler(cell, viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return deletionHandler != nil
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let thread = dataManager.contents[indexPath.row]
        deletionHandler!(thread)
    }
}

private extension ThreadTableViewCell.ViewModel {
    init(thread: AwfulThread, showsTag: Bool, ignoreSticky: Bool) {
        title = thread.title ?? ""
        numberOfPages = Int(thread.numberOfPages)
        
        beenSeen = thread.beenSeen
        killedBy = thread.lastPostAuthorName ?? ""
        postedBy = thread.author?.username ?? ""
        
        unreadPosts = Int(thread.unreadPosts)
        starCategory = thread.starCategory
        
        let tweaks = thread.forum.flatMap { ForumTweaks(forumID: $0.forumID) }
        
        showsTagAndRating = showsTag
        let imageName: String?
        if let tweaks = tweaks , tweaks.showRatingsAsThreadTags {
            let rating = round(thread.rating * 2) / 2
            imageName = NSString(format: "%.1fstars.png", rating) as String
        } else {
            imageName = thread.threadTag?.imageName
        }
        if let
            imageName = imageName,
            let image = ThreadTagLoader.imageNamed(imageName: imageName)
        {
            tag = Tag.Downloaded(image)
        } else {
            let image = ThreadTagLoader.emptyThreadTagImage
            tag = .Unavailable(fallbackImage: image, desiredImageName: imageName ?? "")
        }
        
        if let secondaryTagImageName = thread.secondaryThreadTag?.imageName {
            secondaryTag = ThreadTagLoader.imageNamed(imageName: secondaryTagImageName)
            self.secondaryTagImageName = secondaryTagImageName
        } else {
            secondaryTag = nil
            secondaryTagImageName = nil
        }
        
        let showRatings = tweaks?.showRatings ?? true
        var rating: Int?
        let rounded = lroundf(thread.rating).clamp(interval: 0...5)
        if rounded != 0 {
            rating = rounded
        }
        if showRatings, let rating = rating {
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
