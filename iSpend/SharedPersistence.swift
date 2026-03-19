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
            SubscriptionContribution.self,
            ExpenseCategory.self,
        ])
    }

    static var sharedURL: URL {
        let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return baseURL.appendingPathComponent(storeName)
    }

    static var sharedModelContainer: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, url: sharedURL)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
