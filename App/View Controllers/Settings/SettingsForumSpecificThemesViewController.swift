//  SettingsForumSpecificThemesViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData

final class SettingsForumSpecificThemesViewController: TableViewController {

    private let context: NSManagedObjectContext

    private lazy var resultsController: NSFetchedResultsController<Forum> = {
        let unsorted = Theme.forumsWithSpecificThemes
        let request = NSFetchRequest<Forum>(entityName: Forum.entityName())
        request.returnsObjectsAsFaults = false
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(Forum.forumID), unsorted)
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true), // section
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)]
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    }()

    private var forums: [Forum] {
        return resultsController.fetchedObjects ?? []
    }

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init(style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.hideExtraneousSeparators()

        resultsController.delegate = self
        try! resultsController.performFetch()

        NotificationCenter.default.addObserver(self, selector: #selector(forumSpecificThemeDidChange), name: Theme.themeForForumDidChangeNotification, object: Theme.self)
    }

    @objc private func forumSpecificThemeDidChange(_ notification: Notification) {
        tableView.reloadData()
    }

    // MARK: - UITableViewDataSource and UITableViewDelegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        return forums.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return forums[section].name
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Theme.Mode.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .value1, reuseIdentifier: "cell")
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityTraits.insert(UIAccessibilityTraits.button)
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.textLabel?.textColor = theme["listTextColor"]
        cell.selectedBackgroundColor = theme["listSelectedBackgroundColor"]

        let forum = forums[indexPath.section]
        let mode = Theme.Mode.allCases[indexPath.row]
        let theme = Theme.currentTheme(for: forum, mode: mode)

        cell.textLabel?.text = mode.localizedDescription
        cell.detailTextLabel?.text = theme.descriptiveName

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let forum = forums[indexPath.section]
        let mode = Theme.Mode.allCases[indexPath.row]
        let picker = SettingsThemePickerViewController(forumID: forum.forumID, mode: mode)
        picker.title = "\(forum.name ?? "") \(mode.localizedDescription)"
        show(picker, sender: self)
    }

    // MARK: - Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SettingsForumSpecificThemesViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
}
