import Foundation
import SwiftData

enum WidgetExpenseDirection: String, Codable {
    case spent
    case received
}

@Model
final class BankAccount {
    var name: String
    var bankName: String
    var bankLogoSystemName: String
    var ownerName: String
    var createdAt: Date
    var sortOrder: Int

    init(
        name: String,
        bankName: String,
        bankLogoSystemName: String,
        ownerName: String = "Suyash Belwalkar",
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.name = name
        self.bankName = bankName
        self.bankLogoSystemName = bankLogoSystemName
        self.ownerName = ownerName
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

@Model
final class ExpenseCategory {
    var name: String
    var colorHex: String
    var isParentCategory: Bool

    init(name: String, colorHex: String, isParentCategory: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.isParentCategory = isParentCategory
    }
}

@Model
final class Investment {
    var title: String
    var amount: Double
    var dueDay: Int
    var note: String

    init(title: String, amount: Double, dueDay: Int, note: String = "") {
        self.title = title
        self.amount = amount
        self.dueDay = dueDay
        self.note = note
    }
}

@Model
final class FriendLedgerEntry {
    var friendName: String
    var amount: Double
    var date: Date
    var directionRawValue: String
    var note: String

    init(
        friendName: String,
        amount: Double,
        date: Date = .now,
        directionRawValue: String,
        note: String = ""
    ) {
        self.friendName = friendName
        self.amount = amount
        self.date = date
        self.directionRawValue = directionRawValue
        self.note = note
    }
}

@Model
final class FamilySubscription {
    var title: String
    var amount: Double
    var maxMembers: Int

    init(title: String, amount: Double, maxMembers: Int = 6) {
        self.title = title
        self.amount = amount
        self.maxMembers = maxMembers
    }
}

@Model
final class SubscriptionMember {
    var memberName: String
    var amount: Double
    var paidThroughMonth: Date?
    var subscription: FamilySubscription?

    init(
        memberName: String,
        amount: Double,
        paidThroughMonth: Date? = nil,
        subscription: FamilySubscription? = nil
    ) {
        self.memberName = memberName
        self.amount = amount
        self.paidThroughMonth = paidThroughMonth
        self.subscription = subscription
    }
}

@Model
final class Expense {
    var title: String
    var amount: Double
    var date: Date
    var directionRawValue: String
    var parentContextRawValue: String?
    var note: String
    var account: BankAccount?
    var category: ExpenseCategory?

    init(
        title: String,
        amount: Double,
        date: Date,
        directionRawValue: String,
        parentContextRawValue: String? = nil,
        note: String = "",
        account: BankAccount? = nil,
        category: ExpenseCategory? = nil
    ) {
        self.title = title
        self.amount = amount
        self.date = date
        self.directionRawValue = directionRawValue
        self.parentContextRawValue = parentContextRawValue
        self.note = note
        self.account = account
        self.category = category
    }

    var direction: WidgetExpenseDirection {
        WidgetExpenseDirection(rawValue: directionRawValue) ?? .spent
    }
}

extension ExpenseCategory {
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension Expense {
    func effectiveCategoryColorHex(from categories: [ExpenseCategory]) -> String? {
        if let parentContextRawValue,
           let parentCategory = categories.first(where: { $0.isParentCategory && $0.normalizedName == parentContextRawValue.lowercased() }) {
            return parentCategory.colorHex
        }
        return category?.colorHex
    }
}

enum WidgetSharedPersistence {
    static let appGroupID = "group.me.suyash.belwalkar.iSpend"
    static let storeName = "iSpend.store"

    static var schema: Schema {
        Schema([
            BankAccount.self,
            Expense.self,
            Investment.self,
            FriendLedgerEntry.self,
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

    static var modelContainer: ModelContainer = {
        makeModelContainer()
    }()

    private static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: sharedURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create widget SwiftData container at \(sharedURL.path): \(error)")
        }
    }
}
