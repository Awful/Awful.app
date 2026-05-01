//  MessageListDataSource.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulTheming
import CoreData
import os
import UIKit

private let Log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MessageListDataSource")

final class MessageListDataSource: NSObject {
    weak var deletionDelegate: MessageListDataSourceDeletionDelegate?
    private let resultsController: NSFetchedResultsController<PrivateMessage>
    private let collectionView: UICollectionView
    private let folder: PrivateMessageFolder?
    private var diffableDataSource: UICollectionViewDiffableDataSource<Int, NSManagedObjectID>!

    init(
        managedObjectContext: NSManagedObjectContext,
        collectionView: UICollectionView,
        folder: PrivateMessageFolder?,
        supplementaryViewProvider: @escaping (UICollectionView, String, IndexPath) -> UICollectionReusableView?
    ) throws {
        let fetchRequest = PrivateMessage.makeFetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(PrivateMessage.sentDate), ascending: false)]

        if let folder = folder {
            fetchRequest.predicate = NSPredicate(format: "folder == %@", folder)
        }

        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        self.folder = folder
        self.collectionView = collectionView
        super.init()

        let cellRegistration = UICollectionView.CellRegistration<MessageListCell, NSManagedObjectID> { [weak self] cell, indexPath, _ in
            guard let self else { return }
            cell.viewModel = self.viewModelForMessage(at: indexPath)
            cell.accessories = [.multiselect(displayed: .whenEditing)]
        }

        diffableDataSource = UICollectionViewDiffableDataSource<Int, NSManagedObjectID>(collectionView: collectionView) { collectionView, indexPath, objectID in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: objectID)
        }
        diffableDataSource.supplementaryViewProvider = supplementaryViewProvider

        resultsController.delegate = self
        try resultsController.performFetch()
        applyCurrentSnapshot(animatingDifferences: false)

        NotificationCenter.default.addObserver(self, selector: #selector(dataStoreDidReset), name: .dataStoreDidReset, object: nil)
    }

    @objc private func dataStoreDidReset() {
        // Old store's objects are no longer reachable from the coordinator. Re-fetch so
        // the FRC's cache stops pointing at dangling objectIDs.
        do {
            try resultsController.performFetch()
        } catch {
            Log.error("Failed to re-fetch after data store reset: \(error)")
        }
        applyCurrentSnapshot(animatingDifferences: false)
    }

    private func applyCurrentSnapshot(animatingDifferences: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>()
        snapshot.appendSections([0])
        let objectIDs = (resultsController.fetchedObjects ?? []).map(\.objectID)
        snapshot.appendItems(objectIDs, toSection: 0)
        diffableDataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    func message(at indexPath: IndexPath) -> PrivateMessage {
        return resultsController.object(at: indexPath)
    }

    func indexPath(for message: PrivateMessage) -> IndexPath? {
        return resultsController.indexPath(forObject: message)
    }
}

extension MessageListDataSource: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        let typedSnapshot = snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        diffableDataSource.apply(typedSnapshot, animatingDifferences: true)
    }
}

extension MessageListDataSource {
    private func viewModelForMessage(at indexPath: IndexPath) -> MessageListCell.ViewModel {
        let message = self.message(at: indexPath)
        let theme = Theme.defaultTheme()

        let displayName = message.isSent
            ? (message.to?.username ?? "Unknown")
            : (message.fromUsername ?? "")
        let labelPrefix = message.isSent ? "To: " : ""

        return MessageListCell.ViewModel(
            backgroundColor: theme["listBackgroundColor"]!,
            selectedBackgroundColor: theme["listSelectedBackgroundColor"]!,
            sender: NSAttributedString(string: labelPrefix + displayName, attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSenderFontSizeAdjustment"]!, weight: .semibold),
                .foregroundColor: theme[uicolor: "listSecondaryTextColor"]!]),
            sentDate: message.sentDate ?? .distantPast,
            sentDateAttributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSentDateFontSizeAdjustment"]!, weight: .semibold),
                .foregroundColor: theme[uicolor: "listTextColor"]!],
            sentDateRaw: NSAttributedString(string: sentDateFormatter.string(from: message.sentDate!), attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSentDateFontSizeAdjustment"]!, weight: .semibold),
                .foregroundColor: theme[uicolor: "listSecondaryTextColor"]!]),
            subject: NSAttributedString(string: message.subject ?? "", attributes: [
                .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: theme[double: "messageListSubjectFontSizeAdjustment"]!, weight: .regular),
                .foregroundColor: theme[uicolor: "listTextColor"]!]),
            tagImage: .image(name: message.threadTag?.imageName, placeholder: .privateMessage),
            tagOverlayImage: {
                if message.isSent {
                    let image = UIImage(named: "pmforwarded")?
                        .stroked(with: theme["listBackgroundColor"]!, thickness: 3, quality: 1)
                        .withRenderingMode(.alwaysTemplate)

                    let imageView = UIImageView(image: image)
                    imageView.tintColor = theme["tintColor"]!

                    return imageView
                } else if message.replied {
                    let image = UIImage(named: "pmreplied")?
                        .stroked(with: theme["listBackgroundColor"]!, thickness: 3, quality: 1)
                        .withRenderingMode(.alwaysTemplate)

                    let imageView = UIImageView(image: image)
                    imageView.tintColor = theme["listBackgroundColor"]!

                    return imageView
                } else if message.forwarded && !message.isSent {
                    let image = UIImage(named: "pmforwarded")?
                        .stroked(with: theme["listBackgroundColor"]!, thickness: 3, quality: 1)
                        .withRenderingMode(.alwaysTemplate)

                    let imageView = UIImageView(image: image)
                    imageView.tintColor = theme["listBackgroundColor"]!

                    return imageView
                } else if !message.seen && !message.isSent {
                    let image = UIImage(named: "newpm")
                    let imageView = UIImageView(image: image)

                    return imageView
                } else {
                    return nil
                }
        }())
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
