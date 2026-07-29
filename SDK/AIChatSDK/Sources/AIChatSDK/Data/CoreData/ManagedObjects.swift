import CoreData
import Foundation

@objc(CDProject)
final class CDProject: NSManagedObject {
    @NSManaged var createdAt: Date?
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var updatedAt: Date?

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDProject> {
        NSFetchRequest<CDProject>(entityName: "CDProject")
    }
}

@objc(CDConversation)
final class CDConversation: NSManagedObject {
    @NSManaged var createdAt: Date?
    @NSManaged var id: UUID?
    @NSManaged var modelID: String?
    @NSManaged var providerID: String?
    @NSManaged var projectID: UUID?
    @NSManaged var title: String?
    @NSManaged var updatedAt: Date?
    @NSManaged var messages: NSSet?

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDConversation> {
        NSFetchRequest<CDConversation>(entityName: "CDConversation")
    }
}

@objc(CDMessage)
final class CDMessage: NSManagedObject {
    @NSManaged var content: String?
    @NSManaged var createdAt: Date?
    @NSManaged var errorDescription: String?
    @NSManaged var id: UUID?
    @NSManaged var role: String?
    @NSManaged var status: String?
    @NSManaged var attachments: NSSet?
    @NSManaged var conversation: CDConversation?

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDMessage> {
        NSFetchRequest<CDMessage>(entityName: "CDMessage")
    }
}

@objc(CDAttachment)
final class CDAttachment: NSManagedObject {
    @NSManaged var data: Data?
    @NSManaged var extractedText: String?
    @NSManaged var fileName: String?
    @NSManaged var id: UUID?
    @NSManaged var kind: String?
    @NSManaged var mimeType: String?
    @NSManaged var relativePath: String?
    @NSManaged var sortIndex: Int32
    @NSManaged var message: CDMessage?

    @nonobjc class func fetchRequest() -> NSFetchRequest<CDAttachment> {
        NSFetchRequest<CDAttachment>(entityName: "CDAttachment")
    }
}

@objc(Item)
final class Item: NSManagedObject {
    @NSManaged var timestamp: Date?
}
