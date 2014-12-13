//  DataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

@objc protocol DataSource: UITableViewDataSource {
    weak var delegate: DataSourceDelegate? { get set }
    var numberOfSections: Int { get }
    func itemAtIndexPath(indexPath: NSIndexPath) -> AnyObject
    func indexPathsForItem(item: AnyObject) -> [NSIndexPath]
    
    optional func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String
    optional func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath
}

@objc protocol DataSourceDelegate: NSObjectProtocol {
    optional func dataSource(dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [NSIndexPath])
    optional func dataSource(dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [NSIndexPath])
    optional func dataSource(dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [NSIndexPath])
    optional func dataSource(dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath)
    
    optional func dataSource(dataSource: DataSource, didInsertSections sections: NSIndexSet)
    optional func dataSource(dataSource: DataSource, didRemoveSections sections: NSIndexSet)
    optional func dataSource(dataSource: DataSource, didRefreshSections sections: NSIndexSet)
    optional func dataSource(dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int)
    
    optional func dataSourceDidReloadData(dataSource: DataSource)
    optional func dataSource(dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?)
}

extension AwfulTableViewController: DataSourceDelegate {
    func dataSource(dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }
    
    func dataSource(dataSource: DataSource, didInsertSections sections: NSIndexSet) {
        tableView.insertSections(sections, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRemoveSections sections: NSIndexSet) {
        tableView.deleteSections(sections, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRefreshSections sections: NSIndexSet) {
        tableView.reloadSections(sections, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int) {
        tableView.moveSection(fromSection, toSection: toSection)
    }
    
    func dataSourceDidReloadData(dataSource: DataSource) {
        if visible {
            tableView.reloadData()
        }
    }
    
    func dataSource(dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
        if visible {
            tableView.beginUpdates()
            updates()
            tableView.endUpdates()
            completion?()
        }
    }
}
