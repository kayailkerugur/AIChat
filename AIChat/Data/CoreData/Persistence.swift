//
//  Persistence.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  NSPersistentContainer wrapper. Two entry points:
//  - `shared`   : on-disk store used by the running app
//  - inMemory   : /dev/null-backed store for unit tests & previews
//                 (spec: "repository testleri in-memory persistent store
//                 kullanılarak yazılmalıdır")
//

import CoreData
import os

struct PersistenceController {

    static let shared = PersistenceController()

    /// In-memory store pre-seeded with one sample conversation,
    /// for SwiftUI previews that want visible data.
    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let conversation = CDConversation(context: context)
        conversation.id = UUID()
        conversation.title = "Örnek Sohbet"
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.providerID = "mock"
        conversation.modelID = "mock-fast"

        let message = CDMessage(context: context)
        message.id = UUID()
        message.role = MessageRole.user.rawValue
        message.content = "Merhaba!"
        message.createdAt = Date()
        message.status = MessageStatus.completed.rawValue
        message.conversation = conversation

        do {
            try context.save()
        } catch {
            AppLogger.persistence.error(
                "Preview seed save failed: \(error.localizedDescription)"
            )
        }
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AIChat")

        if inMemory {
            container.persistentStoreDescriptions.first!.url =
                URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // A store that fails to load at launch is unrecoverable for
                // this app (no user data can be shown or written). We log
                // first, then crash intentionally. Note the spec's
                // "don't swallow errors" rule targets SAVE errors — those
                // are thrown to callers in the repository layer instead.
                AppLogger.persistence.critical(
                    "Persistent store failed to load: \(error), \(error.userInfo)"
                )
                fatalError("Persistent store failed to load: \(error)")
            }
        }

        // Background-context writes become visible to the UI context.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
    }

    /// Fresh background context for repository work — long or heavy
    /// operations never block the main thread (spec §5.2).
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
