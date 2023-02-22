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
        let fetchRequest = PrivateMessage.makeFetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(PrivateMessage.sentDate), ascending: false)]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)

        self.tableView = tableView
        super.init()

        try resultsController.performFetch()

        tableView.dataSource = self
        tableView.register(MessageListCell.self, forCellReuseIdentifier: cellReuseIdentifier)

        resultsController.delegate = self
    }

    func message(at indexPath: IndexPath) -> PrivateMessage {
        return resultsController.object(at: indexPath)
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
        @unknown default:
            assertionFailure("handle unknown change type")
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
        @unknown default:
            assertionFailure("handle unknown change type")
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
        let tableWidth = tableView.safeAreaLayoutGuide.layoutFrame.width
        return MessageListCell.heightForViewModel(viewModel, inTableWithWidth: tableWidth)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath) as! MessageListCell
        cell.viewModel = viewModelForMessage(at: indexPath)
        return cell
    }

    private func viewModelForMessage(at indexPath: IndexPath) -> MessageListCell.ViewModel {
        let message = self.message(at: indexPath)
        let theme = Theme.defaultTheme()
          
        return MessageListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!,
            sender: NSAttributedString(string: message.fromUsername ?? "", attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSenderFontSizeAdjustment"]!, weight: .semibold),
                .foregroundColor: theme[color: "listSecondaryTextColor"]!]),
            sentDate: message.sentDate ?? .distantPast,
            sentDateAttributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSentDateFontSizeAdjustment"]!, weight: .semibold),
                .foregroundColor: theme[color: "listTextColor"]!],
            sentDateRaw: NSAttributedString(string: sentDateFormatter.string(from: message.sentDate!), attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSentDateFontSizeAdjustment"]!, weight: .semibold),
                .foregroundColor: theme[color: "listSecondaryTextColor"]!]),
            subject: NSAttributedString(string: message.subject ?? "", attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSubjectFontSizeAdjustment"]!, weight: .regular),
                .foregroundColor: theme[color: "listTextColor"]!]),
            tagImage: .image(name: message.threadTag?.imageName, placeholder: .privateMessage),
            tagOverlayImage: {
                if message.replied {
                    let image = UIImage(named: "pmreplied")?
                        .stroked(with: theme["listBackgroundColor"]!, thickness: 3, quality: 1)
                        .withRenderingMode(.alwaysTemplate)
                    
                    let imageView = UIImageView(image: image)
                    imageView.tintColor = theme["listBackgroundColor"]!
                    
                    return imageView
                } else if message.forwarded {
                    let image = UIImage(named: "pmforwarded")?
                        .stroked(with: theme["listBackgroundColor"]!, thickness: 3, quality: 1)
                        .withRenderingMode(.alwaysTemplate)
                    
                    let imageView = UIImageView(image: image)
                    imageView.tintColor = theme["listBackgroundColor"]!
                    
                    return imageView
                } else if !message.seen {
                    let image = UIImage(named: "newpm")
                    let imageView = UIImageView(image: image)
                    
                    return imageView
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

protocol MessageListDataSourceDeletionDelegate: AnyObject {
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
    formatter.dateFormat = "d MMM YY"
    return formatter
}()

private let sentTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

