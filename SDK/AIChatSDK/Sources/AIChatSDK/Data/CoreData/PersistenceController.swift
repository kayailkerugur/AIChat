import CoreData
import Foundation

public final class PersistenceController: @unchecked Sendable {
    public static let shared = PersistenceController()

    let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        let modelURL = Bundle.module.url(
            forResource: "AIChat",
            withExtension: "momd"
        ) ?? Bundle.module.url(
            forResource: "AIChatPrecompiled",
            withExtension: "momd"
        )
        guard let modelURL,
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("AIChatSDK Core Data model could not be loaded")
        }

        container = NSPersistentContainer(name: "AIChat", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url =
                URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions.first?.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                SDKLogger.persistence.critical(
                    "Persistent store failed to load: \(error), \(error.userInfo)"
                )
                fatalError("Persistent store failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(
            merge: .mergeByPropertyObjectTrumpMergePolicyType
        )
        return context
    }
}
