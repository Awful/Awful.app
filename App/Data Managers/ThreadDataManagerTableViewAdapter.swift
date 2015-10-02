//  ThreadDataManagerTableViewAdapter.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

final class ThreadDataManagerTableViewAdapter: NSObject, UITableViewDataSource, ThreadDataManagerDelegate {
    private let tableView: UITableView
    private let dataManager: ThreadDataManager
    private let cellConfigurationHandler: (ThreadTableViewCell, Thread) -> Void
    var deletionHandler: (Thread -> Void)?
    
    init(tableView: UITableView, dataManager: ThreadDataManager, cellConfigurationHandler: (ThreadTableViewCell, Thread) -> Void) {
        self.tableView = tableView
        self.dataManager = dataManager
        self.cellConfigurationHandler = cellConfigurationHandler
        super.init()
    }
    
    // MARK: ThreadDataManagerDelegate
    
    func dataManagerWillChangeContent(dataManager: ThreadDataManager) {
        tableView.beginUpdates()
    }
    
    func dataManager(dataManager: ThreadDataManager, didInsertRowAtIndexPath indexPath: NSIndexPath) {
        tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func dataManager(dataManager: ThreadDataManager, didDeleteRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func dataManager(dataManager: ThreadDataManager, didMoveRowAtIndexPath fromIndexPath: NSIndexPath, toRowAtIndexPath toIndexPath: NSIndexPath) {
        tableView.moveRowAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
    }
    
    func dataManager(dataManager: ThreadDataManager, didUpdateRowAtIndexPath indexPath: NSIndexPath) {
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    
    func dataManagerDidChangeContent(dataManager: ThreadDataManager) {
        tableView.endUpdates()
    }
    
    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataManager.threads.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ThreadTableViewCell.identifier, forIndexPath: indexPath) as! ThreadTableViewCell
        let thread = dataManager.threads[indexPath.row]
        cellConfigurationHandler(cell, thread)
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
