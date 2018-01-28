//  MessageListDataSource.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get(level: .debug)

final class MessageListDataSource: NSObject {
    weak var deletionDelegate: MessageListDataSourceDeletionDelegate?
    private let showsTag: Bool
    private let resultsController: NSFetchedResultsController<PrivateMessage>
    private let tableView: UITableView

    init(managedObjectContext: NSManagedObjectContext, tableView: UITableView, showsTag: Bool) throws {
        let fetchRequest = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName())
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(PrivateMessage.sentDate), ascending: false)]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)

        self.showsTag = showsTag
        self.tableView = tableView
        super.init()

        try resultsController.performFetch()

        tableView.dataSource = self
        tableView.register(UINib(nibName: "MessageCell", bundle: Bundle(for: MessageCell.self)), forCellReuseIdentifier: cellReuseIdentifier)

        resultsController.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(threadTagLoaderNewImageAvailable), name: ThreadTagLoader.NewImageAvailableNotification.name, object: ThreadTagLoader.sharedLoader)
    }

    func message(at indexPath: IndexPath) -> PrivateMessage {
        return resultsController.object(at: indexPath)
    }

    @objc private func threadTagLoaderNewImageAvailable(_ notification: Notification) {
        // TODO: this
    }
}

private let cellReuseIdentifier = "Message"

extension MessageListDataSource: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move, .update:
            assertionFailure("why")
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at oldIndexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .delete:
            tableView.deleteRows(at: [oldIndexPath!], with: .fade)
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .move:
            tableView.deleteRows(at: [oldIndexPath!], with: .fade)
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [oldIndexPath!], with: .none)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

extension MessageListDataSource: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections?.first?.numberOfObjects ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! MessageCell
        let message = self.message(at: indexPath)

        cell.showsTag = showsTag
        if showsTag {
            cell.tagImageView.image = message
                .threadTag?
                .imageName
                .map { ThreadTagLoader.imageNamed($0) }
                ?? ThreadTagLoader.emptyPrivateMessageImage
        } else {
            cell.tagImageView.image = nil
        }

        if message.replied {
            cell.tagOverlayImageView.image = UIImage(named: "pmreplied.gif")
        } else if message.forwarded {
            cell.tagOverlayImageView.image = UIImage(named: "pmforwarded.gif")
        } else if !message.seen {
            cell.tagOverlayImageView.image = UIImage(named: "newpm.gif")
        } else {
            cell.tagOverlayImageView.image = nil
        }

        cell.senderLabel.text = message.fromUsername
        let sentDateString = stringForSentDate(message.sentDate)
        cell.dateLabel.text = sentDateString
        cell.subjectLabel.text = message.subject

        cell.accessibilityLabel = String(
            format: LocalizedString("private-messages-list.message.accessibility-label"),
            message.fromUsername ?? "",
            message.subject ?? "",
            sentDateString)

        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let message = self.message(at: indexPath)
        deletionDelegate?.didDeleteMessage(message, in: self)
    }
}

protocol MessageListDataSourceDeletionDelegate: class {
    func didDeleteMessage(_ message: PrivateMessage, in dataSource: MessageListDataSource)
}

private func stringForSentDate(_ date: Date?) -> String {
    guard let date = date else { return "" }

    let calendar = Calendar.current
    let units: Set<Calendar.Component> = [.day, .month, .year]
    let sent = calendar.dateComponents(units, from: date)
    let today = calendar.dateComponents(units, from: Date())
    let formatter = sent == today ? sentTimeFormatter : sentDateFormatter
    return formatter.string(from: date)
}

private let sentDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

private let sentTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()
