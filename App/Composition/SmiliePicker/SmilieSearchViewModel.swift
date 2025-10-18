//  SmilieSearchViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Combine
import CoreData
import Foundation
import Smilies

@MainActor
final class SmilieSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var allSmilies: [SmilieSection] = []
    @Published var searchResults: [Smilie] = []
    @Published var recentlyUsedSmilies: [Smilie] = []
    @Published var isLoading = true
    @Published var loadError: String?
    
    private let dataStore: SmilieDataStore
    private var cancellables = Set<AnyCancellable>()
    
    struct SmilieSection {
        let title: String
        let smilies: [Smilie]
    }
    
    init(dataStore: SmilieDataStore) {
        self.dataStore = dataStore
        
        setupSearchSubscription()
        loadSmilies()
    }
    
    private func setupSearchSubscription() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(searchText)
            }
            .store(in: &cancellables)
    }
    
    func loadSmilies() {
        Task {
            isLoading = true
            loadError = nil
            
            await loadRecentlyUsed()
            await loadAllSmilies()
            
            self.isLoading = false
        }
    }
    
    private func loadRecentlyUsed() async {
        guard let context = dataStore.managedObjectContext else { return }
        await context.perform { [weak self] in
            guard let self = self else { return }
            
            // First fetch SmilieMetadata entities that have a lastUsedDate
            let metadataRequest = NSFetchRequest<NSManagedObject>(entityName: "SmilieMetadata")
            metadataRequest.predicate = NSPredicate(format: "lastUsedDate != nil")
            metadataRequest.sortDescriptors = [
                NSSortDescriptor(key: "lastUsedDate", ascending: false)
            ]
            metadataRequest.fetchLimit = 8
            
            do {
                let metadataResults = try context.fetch(metadataRequest)
                
                // Extract smilie texts from metadata
                let smilieTexts = metadataResults.compactMap { metadata -> String? in
                    metadata.value(forKey: "smilieText") as? String
                }
                
                // Now fetch the corresponding Smilie entities
                if !smilieTexts.isEmpty {
                    let smilieRequest = NSFetchRequest<Smilie>(entityName: "Smilie")
                    smilieRequest.predicate = NSPredicate(format: "text IN %@", smilieTexts)
                    smilieRequest.returnsObjectsAsFaults = false
                    
                    let smilies = try context.fetch(smilieRequest)
                    
                    // Sort smilies based on the order from metadata
                    // Handle potential duplicates by keeping the first occurrence
                    var textToSmilie: [String: Smilie] = [:]
                    for smilie in smilies {
                        if textToSmilie[smilie.text] == nil {
                            textToSmilie[smilie.text] = smilie
                        }
                    }
                    let sortedSmilies = smilieTexts.compactMap { textToSmilie[$0] }
                    
                    Task { @MainActor in
                        self.recentlyUsedSmilies = sortedSmilies
                    }
                }
            } catch {
                print("Error fetching recently used smilies: \(error)")
            }
        }
    }
    
    private func loadAllSmilies() async {
        guard let context = dataStore.managedObjectContext else { return }
        await context.perform { [weak self] in
            guard let self = self else { return }
            
            let fetchRequest = NSFetchRequest<Smilie>(entityName: "Smilie")
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Smilie.section, ascending: true),
                NSSortDescriptor(keyPath: \Smilie.text, ascending: true)
            ]
            // Ensure objects are not returned as faults
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let smilies = try context.fetch(fetchRequest)
                
                // Deduplicate by text while preserving order
                var seenTexts = Set<String>()
                var deduplicatedSmilies: [Smilie] = []
                for smilie in smilies {
                    if !seenTexts.contains(smilie.text) {
                        seenTexts.insert(smilie.text)
                        deduplicatedSmilies.append(smilie)
                    }
                }
                
                let grouped = Dictionary(grouping: deduplicatedSmilies) { $0.section ?? "Other" }
                
                // Create sections preserving the order from the data
                // Since we're already sorting by section in the fetch request,
                // we can maintain that order by using the first appearance of each section
                var sectionOrder: [String] = []
                
                for smilie in deduplicatedSmilies {
                    let section = smilie.section ?? "Other"
                    if !sectionOrder.contains(section) {
                        sectionOrder.append(section)
                    }
                }
                
                let sections = sectionOrder.compactMap { sectionTitle -> SmilieSection? in
                    guard let smilies = grouped[sectionTitle] else { return nil }
                    // Sort smilies alphabetically within each section
                    let sortedSmilies = smilies.sorted { $0.text < $1.text }
                    return SmilieSection(title: sectionTitle, smilies: sortedSmilies)
                }
                
                Task { @MainActor in
                    self.allSmilies = sections
                }
            } catch {
                print("Error fetching all smilies: \(error)")
            }
        }
    }
    
    private func performSearch(_ searchText: String) {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        Task {
            guard let context = dataStore.managedObjectContext else { return }
            await context.perform { [weak self] in
                guard let self = self else { return }
                
                let fetchRequest = NSFetchRequest<Smilie>(entityName: "Smilie")
                fetchRequest.predicate = NSPredicate(
                    format: "text CONTAINS[cd] %@ OR summary CONTAINS[cd] %@",
                    searchText, searchText
                )
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Smilie.text, ascending: true)
                ]
                fetchRequest.returnsObjectsAsFaults = false
                
                do {
                    let results = try context.fetch(fetchRequest)
                    
                    Task { @MainActor in
                        self.searchResults = results
                    }
                } catch {
                    print("Error searching smilies: \(error)")
                    Task { @MainActor in
                        self.searchResults = []
                    }
                }
            }
        }
    }
    
    func updateLastUsedDate(for smilie: Smilie) {
        guard let context = dataStore.managedObjectContext else { return }
        let smilieID = smilie.objectID
        Task {
            await context.perform {
                guard let smilie = context.object(with: smilieID) as? Smilie,
                      let smilieText = smilie.text else { return }

                let fetchRequest = NSFetchRequest<Smilie>(entityName: "Smilie")
                fetchRequest.predicate = NSPredicate(format: "text == %@", smilieText)
                fetchRequest.fetchLimit = 1

                do {
                    if let smilie = try context.fetch(fetchRequest).first {
                        smilie.metadata.lastUsedDate = Date()
                        try context.save()
                    }
                } catch {
                    print("Error saving last used date: \(error)")
                }
            }
        }
    }
}
