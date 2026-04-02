import Foundation
import SwiftData

enum SharedPersistence {
    static let appGroupID = "group.me.suyash.belwalkar.iSpend"
    static let storeName = "iSpend.store"

    static var schema: Schema {
        Schema([
            BankAccount.self,
            Expense.self,
            FriendLedgerEntry.self,
            Investment.self,
            FamilySubscription.self,
            SubscriptionMember.self,
            ExpenseCategory.self,
        ])
    }

    static var sharedURL: URL {
        let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent(storeName)
    }

    static var sharedModelContainer: ModelContainer = {
        makeModelContainer()
    }()

    private static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: sharedURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create shared SwiftData container at \(sharedURL.path): \(error)")
        }
    }
}
