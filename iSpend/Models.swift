import Foundation
import SwiftData
import SwiftUI

enum ExpenseDirection: String, Codable, CaseIterable, Identifiable {
    case spent
    case received

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .spent:
            .red
        case .received:
            .green
        }
    }
}

enum FriendDirection: String, Codable, CaseIterable, Identifiable {
    case owesMe
    case iOwe

    var id: String { rawValue }
}

enum ExpenseParentContext: String, Codable, CaseIterable, Identifiable {
    case family
    case friends

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

@Model
final class BankAccount {
    var name: String
    var bankName: String
    var bankLogoSystemName: String
    var ownerName: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \Expense.account)
    var expenses: [Expense] = []

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
        date: Date = .now,
        direction: ExpenseDirection,
        parentContext: ExpenseParentContext? = nil,
        category: ExpenseCategory?,
        note: String = "",
        account: BankAccount?
    ) {
        self.title = title
        self.amount = amount
        self.date = date
        self.directionRawValue = direction.rawValue
        self.parentContextRawValue = parentContext?.rawValue
        self.note = note
        self.account = account
        self.category = category
    }

    var direction: ExpenseDirection {
        get { ExpenseDirection(rawValue: directionRawValue) ?? .spent }
        set { directionRawValue = newValue.rawValue }
    }

    var parentContext: ExpenseParentContext? {
        get {
            guard let parentContextRawValue else { return nil }
            return ExpenseParentContext(rawValue: parentContextRawValue)
        }
        set {
            parentContextRawValue = newValue?.rawValue
        }
    }
}

@Model
final class ExpenseCategory {
    var name: String
    var colorHex: String

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
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
        direction: FriendDirection,
        note: String = ""
    ) {
        self.friendName = friendName
        self.amount = amount
        self.date = date
        self.directionRawValue = direction.rawValue
        self.note = note
    }

    var direction: FriendDirection {
        get { FriendDirection(rawValue: directionRawValue) ?? .owesMe }
        set { directionRawValue = newValue.rawValue }
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
final class FamilySubscription {
    var title: String
    var amount: Double
    var maxMembers: Int

    @Relationship(deleteRule: .cascade, inverse: \SubscriptionContribution.subscription)
    var contributions: [SubscriptionContribution] = []

    init(title: String, amount: Double, maxMembers: Int = 6) {
        self.title = title
        self.amount = amount
        self.maxMembers = maxMembers
    }
}

@Model
final class SubscriptionContribution {
    var memberName: String
    var monthKey: String
    var amount: Double
    var isPaid: Bool
    var paidOn: Date?
    var subscription: FamilySubscription?

    init(
        memberName: String,
        monthKey: String,
        amount: Double,
        isPaid: Bool = false,
        paidOn: Date? = nil,
        subscription: FamilySubscription?
    ) {
        self.memberName = memberName
        self.monthKey = monthKey
        self.amount = amount
        self.isPaid = isPaid
        self.paidOn = paidOn
        self.subscription = subscription
    }
}

extension FamilySubscription {
    static func monthKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
