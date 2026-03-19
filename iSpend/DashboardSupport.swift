import Foundation
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ExpenseTotals {
    let today: Double
    let week: Double
    let month: Double
}

struct FriendSummary {
    let owedToMe: Double
    let iOwe: Double
    let names: [String]
}

struct YearlyExpenseTotals {
    let today: Double
    let week: Double
    let month: Double
    let year: Double
}

enum HomeSheet: Identifiable {
    case addAccount
    case editAccount(BankAccount)
    case addExpense
    case editExpense(Expense)
    case addInvestment
    case addFriendEntry
    case addSubscription
    case addSubscriptionMember(FamilySubscription)
    case editSubscriptionMember(SubscriptionMember)
    case addCategory
    case editCategory(ExpenseCategory)

    var id: String {
        switch self {
        case .addAccount:
            "add-account"
        case let .editAccount(account):
            "edit-account-\(account.persistentModelID)"
        case .addExpense:
            "add-expense"
        case let .editExpense(expense):
            "edit-\(expense.persistentModelID)"
        case .addInvestment:
            "add-investment"
        case .addFriendEntry:
            "add-friend-entry"
        case .addSubscription:
            "add-subscription"
        case let .addSubscriptionMember(subscription):
            "add-subscription-member-\(subscription.persistentModelID)"
        case let .editSubscriptionMember(member):
            "edit-subscription-member-\(member.persistentModelID)"
        case .addCategory:
            "add-category"
        case let .editCategory(category):
            "edit-category-\(category.persistentModelID)"
        }
    }
}

extension Double {
    func currency(_ code: String = "INR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    func currencyParts(_ code: String = "INR") -> (symbol: String, value: String) {
        let formatted = currency(code)
        let symbol = "₹"
        if formatted.hasPrefix(symbol) {
            return (symbol, String(formatted.dropFirst(symbol.count)))
        }
        return (symbol, formatted)
    }
}

struct CurrencyText: View {
    let amount: Double
    var code: String = "INR"

    var body: some View {
        let parts = amount.currencyParts(code)
        return HStack(spacing: 0) {
            Text(parts.symbol)
                .fontDesign(.default)
            Text(parts.value)
        }
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch value.count {
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xff, int >> 8 & 0xff, int & 0xff)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xff, int & 0xff)
        default:
            (a, r, g, b) = (255, 120, 120, 120)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        #if canImport(UIKit)
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let resolved: (CGFloat, CGFloat, CGFloat)
        if components.count >= 3 {
            resolved = (components[0], components[1], components[2])
        } else {
            resolved = (components[0], components[0], components[0])
        }
        return String(
            format: "#%02X%02X%02X",
            Int(resolved.0 * 255),
            Int(resolved.1 * 255),
            Int(resolved.2 * 255)
        )
        #else
        return "#808080"
        #endif
    }
}

extension Array where Element == Expense {
    func totals(for account: BankAccount?, calendar: Calendar = .current) -> ExpenseTotals {
        guard let account else {
            return ExpenseTotals(today: 0, week: 0, month: 0)
        }

        let accountExpenses = self.filter { $0.account?.persistentModelID == account.persistentModelID && $0.direction == .spent }
        let now = Date()
        let todayInterval = calendar.dateInterval(of: .day, for: now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)

        let today = accountExpenses
            .filter { todayInterval?.contains($0.date) == true }
            .reduce(0) { $0 + $1.amount }
        let week = accountExpenses
            .filter { weekInterval?.contains($0.date) == true }
            .reduce(0) { $0 + $1.amount }
        let month = accountExpenses
            .filter { monthInterval?.contains($0.date) == true }
            .reduce(0) { $0 + $1.amount }

        return ExpenseTotals(today: today, week: week, month: month)
    }

    func yearlyTotals(for account: BankAccount?, calendar: Calendar = .current) -> YearlyExpenseTotals {
        guard let account else {
            return YearlyExpenseTotals(today: 0, week: 0, month: 0, year: 0)
        }

        let accountExpenses = self.filter { $0.account?.persistentModelID == account.persistentModelID && $0.direction == .spent }
        let now = Date()
        let todayInterval = calendar.dateInterval(of: .day, for: now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let yearInterval = calendar.dateInterval(of: .year, for: now)
        return YearlyExpenseTotals(
            today: accountExpenses.filter { todayInterval?.contains($0.date) == true }.reduce(0) { $0 + $1.amount },
            week: accountExpenses.filter { weekInterval?.contains($0.date) == true }.reduce(0) { $0 + $1.amount },
            month: accountExpenses.filter { monthInterval?.contains($0.date) == true }.reduce(0) { $0 + $1.amount },
            year: accountExpenses.filter { yearInterval?.contains($0.date) == true }.reduce(0) { $0 + $1.amount }
        )
    }

    var netTotal: Double {
        reduce(0) { partialResult, expense in
            partialResult + (expense.direction == .received ? expense.amount : expense.amount * -1)
        }
    }

    var expenseTotal: Double {
        filter { $0.direction == .spent }.reduce(0) { $0 + $1.amount }
    }
}

extension Array where Element == FriendLedgerEntry {
    var summary: FriendSummary {
        let owedToMe = filter { $0.direction == .owesMe }.reduce(0) { $0 + $1.amount }
        let iOwe = filter { $0.direction == .iOwe }.reduce(0) { $0 + $1.amount }
        let names = Array<String>(Set<String>(self.map { $0.friendName })).sorted()
        return FriendSummary(owedToMe: owedToMe, iOwe: iOwe, names: names)
    }
}
