//  MessageListDataSource.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get()

final class MessageListDataSource: NSObject {
    weak var deletionDelegate: MessageListDataSourceDeletionDelegate?
    private let resultsController: NSFetchedResultsController<PrivateMessage>
    private let tableView: UITableView

    init(managedObjectContext: NSManagedObjectContext, tableView: UITableView) throws {
        let fetchRequest = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName())
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(PrivateMessage.sentDate), ascending: false)]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)

        self.tableView = tableView
        super.init()

        try resultsController.performFetch()

        tableView.dataSource = self
        tableView.register(MessageListCell.self, forCellReuseIdentifier: cellReuseIdentifier)

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

private let cellReuseIdentifier = "MessageCell"

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

    // Actually UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let viewModel = viewModelForMessage(at: indexPath)
        return MessageListCell.heightForViewModel(viewModel, inTableWithWidth: tableView.bounds.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! MessageListCell
        cell.viewModel = viewModelForMessage(at: indexPath)
        return cell
    }

    private func viewModelForMessage(at indexPath: IndexPath) -> MessageListCell.ViewModel {
        let message = self.message(at: indexPath)
        let theme = Theme.currentTheme
        return MessageListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!,
            sender: NSAttributedString(string: message.fromUsername ?? "", attributes: [
                .font: UIFont.boldSystemFont(ofSize: UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFont.TextStyle.subheadline).pointSize),
                .foregroundColor: (theme["listTextColor"] as UIColor?)!]),
            sentDate: message.sentDate ?? .distantPast,
            sentDateAttributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: -2),
                .foregroundColor: (theme["listTextColor"] as UIColor?)!],
            subject: NSAttributedString(string: message.subject ?? "", attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: -2),
                .foregroundColor: (theme["listTextColor"] as UIColor?)!]),
            tagImage: message
                .threadTag?
                .imageName
                .flatMap { ThreadTagLoader.imageNamed($0) }
                ?? ThreadTagLoader.emptyPrivateMessageImage,
            tagOverlayImage: {
                if message.replied {
                    return UIImage(named: "pmreplied")
                } else if message.forwarded {
                    return UIImage(named: "pmforwarded")
                } else if !message.seen {
                    return UIImage(named: "newpm")
                } else {
                    return nil
                }
        }())
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
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
