//  ForumDataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// Lists all the forums, in groups, allowing forums to hide or show their subforums.
final class ForumTreeDataSource: FetchedDataSource {
    init(managedObjectContext: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest(entityName: ForumMetadata.entityName())
        fetchRequest.predicate = NSPredicate(format: "visibleInForumList = YES")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "forum.group.index", ascending: true),
            NSSortDescriptor(key: "forum.index", ascending: true)
        ]
        super.init(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: "forum.group.index")
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Forum", forIndexPath: indexPath) as! ForumTreeCell
        let metadata = itemAtIndexPath(indexPath) as! ForumMetadata
        let forum = metadata.forum
        
        var accessibilityLabel = forum.name ?? ""
        
        var subforumDepth = -1
        var currentForum: Forum! = forum
        repeat {
            subforumDepth++
            currentForum = currentForum.parentForum
        } while currentForum != nil
        cell.subforumDepth = subforumDepth
        
        let disclosureButton = cell.disclosureButton
        if forum.childForums.count > 0 {
            disclosureButton.hidden = false
            if metadata.showsChildrenInForumList {
                disclosureButton.selected = true
                disclosureButton.accessibilityLabel = "Hide subforums"
            } else {
                disclosureButton.selected = false
                disclosureButton.accessibilityLabel = "Expand subforums"
            }
            let s = forum.childForums.count == 1 ? "" : "s"
            accessibilityLabel += ". \(forum.childForums.count) subforum\(s)"
        } else {
            disclosureButton.hidden = true
        }
        cell.nameLabel.text = forum.name
        cell.favoriteButton.hidden = metadata.favorite

        cell.accessibilityLabel = accessibilityLabel
        return cell
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionInfo = fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
        if let anyMetadata = sectionInfo.objects!.first as? ForumMetadata {
            return anyMetadata.forum.group?.name
        } else {
            return nil
        }
    }
}

/// Lists all forums with a gold star.
final class ForumFavoriteDataSource: FetchedDataSource {
    init(managedObjectContext: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest(entityName: ForumMetadata.entityName())
        fetchRequest.predicate = NSPredicate(format: "favorite = YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "favoriteIndex", ascending: true)]
        
        // Giving a nil sectionNameKeyPath would have the fetched results controller always return one section, even when it's empty. By giving this trivial sectionNameKeyPath, the FRC will return zero sections if it is empty and one section if it is not.
        super.init(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: "favorite")
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Favorite", forIndexPath: indexPath) as! ForumCell
        let metadata = itemAtIndexPath(indexPath) as! ForumMetadata
        cell.nameLabel.text = metadata.forum.name
        return cell
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Favorites"
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let metadata = itemAtIndexPath(indexPath) as! ForumMetadata
            userDrivenChange {
                let sections = self.fetchedResultsController.sections as [NSFetchedResultsSectionInfo]?
                let deleteEntireSection = sections![indexPath.section].numberOfObjects == 1
                
                metadata.favorite = false
                metadata.managedObjectContext?.processPendingChanges()
                
                if deleteEntireSection {
                    self.delegate?.dataSource?(self, didRemoveSections: NSIndexSet(index: indexPath.section))
                } else {
                    self.delegate?.dataSource?(self, didRemoveItemsAtIndexPaths: [indexPath])
                }
            }
        }
    }
    
    func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        userDrivenChange {
            var favorites = self.fetchedResultsController.fetchedObjects as! [ForumMetadata]
            let moved = favorites.removeAtIndex(fromIndexPath.row)
            favorites.insert(moved, atIndex: toIndexPath.row)
            for (i, metadata) in favorites.enumerate() {
                metadata.favoriteIndex = Int32(i)
            }
        }
    }
}
