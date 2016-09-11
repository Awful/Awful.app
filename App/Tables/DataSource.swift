//  DataSource.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

@objc protocol DataSource: UITableViewDataSource {
    weak var delegate: DataSourceDelegate? { get set }
    var numberOfSections: Int { get }
    func itemAtIndexPath(_ indexPath: IndexPath) -> AnyObject
    func indexPathsForItem(_ item: AnyObject) -> [IndexPath]
    
    @objc optional func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: IndexPath) -> String
    @objc optional func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAtIndexPath sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath
}

@objc protocol DataSourceDelegate: NSObjectProtocol {
    @objc optional func dataSource(_ dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [IndexPath])
    @objc optional func dataSource(_ dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [IndexPath])
    @objc optional func dataSource(_ dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [IndexPath])
    @objc optional func dataSource(_ dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: IndexPath, toIndexPath: IndexPath)
    
    @objc optional func dataSource(_ dataSource: DataSource, didInsertSections sections: IndexSet)
    @objc optional func dataSource(_ dataSource: DataSource, didRemoveSections sections: IndexSet)
    @objc optional func dataSource(_ dataSource: DataSource, didRefreshSections sections: IndexSet)
    @objc optional func dataSource(_ dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int)
    
    @objc optional func dataSourceDidReloadData(_ dataSource: DataSource)
    @objc optional func dataSource(_ dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?)
}

extension TableViewController: DataSourceDelegate {
    func dataSource(_ dataSource: DataSource, didInsertItemsAtIndexPaths indexPaths: [IndexPath]) {
        tableView.insertRows(at: indexPaths as [IndexPath], with: .automatic)
    }
    
    func dataSource(_ dataSource: DataSource, didRemoveItemsAtIndexPaths indexPaths: [IndexPath]) {
        tableView.deleteRows(at: indexPaths as [IndexPath], with: .automatic)
    }
    
    func dataSource(_ dataSource: DataSource, didRefreshItemsAtIndexPaths indexPaths: [IndexPath]) {
        tableView.reloadRows(at: indexPaths as [IndexPath], with: .automatic)
    }
    
    func dataSource(_ dataSource: DataSource, didMoveItemAtIndexPath fromIndexPath: IndexPath, toIndexPath: IndexPath) {
        tableView.moveRow(at: fromIndexPath as IndexPath, to: toIndexPath as IndexPath)
    }
    
    func dataSource(_ dataSource: DataSource, didInsertSections sections: IndexSet) {
        tableView.insertSections(sections as IndexSet, with: .automatic)
    }
    
    func dataSource(_ dataSource: DataSource, didRemoveSections sections: IndexSet) {
        tableView.deleteSections(sections as IndexSet, with: .automatic)
    }
    
    func dataSource(_ dataSource: DataSource, didRefreshSections sections: IndexSet) {
        tableView.reloadSections(sections as IndexSet, with: .automatic)
    }
    
    func dataSource(_ dataSource: DataSource, didMoveSection fromSection: Int, toSection: Int) {
        tableView.moveSection(fromSection, toSection: toSection)
    }
    
    func dataSourceDidReloadData(_ dataSource: DataSource) {
        tableView.reloadData()
    }
    
    func dataSource(_ dataSource: DataSource, performBatchUpdates updates: () -> Void, completion: (() -> Void)?) {
        tableView.beginUpdates()
        updates()
        tableView.endUpdates()
        completion?()
    }
}
