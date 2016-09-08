//  DataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

@objc protocol DataSource: UITableViewDataSource {
    weak var delegate: DataSourceDelegate? { get set }
    var numberOfSections: Int { get }
    func itemAtIndexPath(indexPath: NSIndexPath) -> AnyObject
    func indexPathsForItem(item: AnyObject) -> [NSIndexPath]
    
    @objc optional func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String
    @objc optional func tableView(tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: NSIndexPath, toProposedIndexPath proposedDestinationIndexPath: NSIndexPath) -> NSIndexPath
}

@objc protocol DataSourceDelegate: NSObjectProtocol {
    @objc optional func dataSource(dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [NSIndexPath])
    @objc optional func dataSource(dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [NSIndexPath])
    @objc optional func dataSource(dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [NSIndexPath])
    @objc optional func dataSource(dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath)
    
    @objc optional func dataSource(dataSource: DataSource, didInsertSections sections: NSIndexSet)
    @objc optional func dataSource(dataSource: DataSource, didRemoveSections sections: NSIndexSet)
    @objc optional func dataSource(dataSource: DataSource, didRefreshSections sections: NSIndexSet)
    @objc optional func dataSource(dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int)
    
    @objc optional func dataSourceDidReloadData(dataSource: DataSource)
    @objc optional func dataSource(dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?)
}

extension TableViewController: DataSourceDelegate {
    func dataSource(dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.insertRows(at: indexPaths as [IndexPath], with: .automatic)
    }
    
    func dataSource(dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.deleteRowsAtIndexPaths(indexPaths as [IndexPath], withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [NSIndexPath]) {
        tableView.reloadRowsAtIndexPaths(indexPaths as [IndexPath], withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
        tableView.moveRowAtIndexPath(fromIndexPath as IndexPath, toIndexPath: toIndexPath as IndexPath)
    }
    
    func dataSource(dataSource: DataSource, didInsertSections sections: NSIndexSet) {
        tableView.insertSections(sections as IndexSet, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRemoveSections sections: NSIndexSet) {
        tableView.deleteSections(sections as IndexSet, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didRefreshSections sections: NSIndexSet) {
        tableView.reloadSections(sections as IndexSet, withRowAnimation: .Automatic)
    }
    
    func dataSource(dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int) {
        tableView.moveSection(fromSection, toSection: toSection)
    }
    
    func dataSourceDidReloadData(dataSource: DataSource) {
        tableView.reloadData()
    }
    
    func dataSource(dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
        tableView.beginUpdates()
        updates()
        tableView.endUpdates()
        completion?()
    }
}
