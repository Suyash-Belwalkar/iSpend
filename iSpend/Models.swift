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
    case gym

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
    var isParentCategory: Bool

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(name: String, colorHex: String, isParentCategory: Bool = false) {
        self.name = name
        self.colorHex = colorHex
        self.isParentCategory = isParentCategory
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

    @Relationship(deleteRule: .cascade, inverse: \SubscriptionMember.subscription)
    var members: [SubscriptionMember] = []

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
        subscription: FamilySubscription?
    ) {
        self.memberName = memberName
        self.amount = amount
        self.paidThroughMonth = paidThroughMonth
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

extension SubscriptionMember {
    var isCurrentMonthPaid: Bool {
        guard let paidThroughMonth else { return false }
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let paidThroughStart = calendar.date(from: calendar.dateComponents([.year, .month], from: paidThroughMonth)) ?? paidThroughMonth
        return paidThroughStart >= currentMonthStart
    }

    var paidThroughLabel: String {
        guard let paidThroughMonth else { return "Not paid" }
        return FamilySubscription.monthKey(from: paidThroughMonth)
    }
}

extension ExpenseCategory {
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension ExpenseParentContext {
    var normalizedName: String {
        title.lowercased()
    }
}

extension Expense {
    func effectiveCategoryName(from categories: [ExpenseCategory]) -> String? {
        if let parentContext,
           let parentCategory = categories.first(where: { $0.isParentCategory && $0.normalizedName == parentContext.normalizedName }) {
            return parentCategory.name
        }
        return category?.name
    }

    func effectiveCategoryColorHex(from categories: [ExpenseCategory]) -> String? {
        if let parentContext,
           let parentCategory = categories.first(where: { $0.isParentCategory && $0.normalizedName == parentContext.normalizedName }) {
            return parentCategory.colorHex
        }
        return category?.colorHex
    }
}

extension FriendLedgerEntry {
    private static let settledMarker = "[[SETTLED]] "

    var isSettled: Bool {
        get { note.hasPrefix(Self.settledMarker) }
        set {
            let visible = visibleNote
            note = newValue ? Self.settledMarker + visible : visible
        }
    }

    var visibleNote: String {
        note.hasPrefix(Self.settledMarker) ? String(note.dropFirst(Self.settledMarker.count)) : note
    }
}
