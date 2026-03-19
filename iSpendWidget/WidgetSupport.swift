import AppIntents
import Foundation
import SwiftData
import SwiftUI

struct WidgetAccountEntity: AppEntity, Identifiable {
    let id: String
    let name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Account")
    static var defaultQuery = WidgetAccountQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WidgetAccountQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WidgetAccountEntity] {
        allAccounts().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [WidgetAccountEntity] {
        allAccounts()
    }

    @MainActor
    func defaultResult() async -> WidgetAccountEntity? {
        allAccounts().first
    }

    @MainActor
    private func allAccounts() -> [WidgetAccountEntity] {
        let descriptor = FetchDescriptor<BankAccount>(sortBy: [SortDescriptor(\.sortOrder)])
        let accounts = (try? WidgetSharedPersistence.modelContainer.mainContext.fetch(descriptor)) ?? []
        return accounts.map {
            WidgetAccountEntity(id: $0.name, name: $0.name)
        }
    }
}

struct SelectAccountIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Account"
    static var description = IntentDescription("Choose which account to display in the widget.")

    @Parameter(title: "Account")
    var account: WidgetAccountEntity?
}

struct WidgetSnapshot {
    let accountName: String
    let today: Double
    let week: Double
    let month: Double
    let colors: [Color]
}

enum WidgetDataLoader {
    @MainActor
    static func snapshot(for intent: SelectAccountIntent) -> WidgetSnapshot {
        let context = WidgetSharedPersistence.modelContainer.mainContext
        let accountDescriptor = FetchDescriptor<BankAccount>(sortBy: [SortDescriptor(\.sortOrder)])
        let accounts = (try? context.fetch(accountDescriptor)) ?? []

        let selectedAccount = accounts.first {
            $0.name == intent.account?.id
        } ?? accounts.first

        guard let selectedAccount else {
            return WidgetSnapshot(
                accountName: "No Account",
                today: 0,
                week: 0,
                month: 0,
                colors: [Color.blue, Color.cyan, Color.indigo]
            )
        }

        let expenseDescriptor = FetchDescriptor<Expense>()
        let allExpenses = (try? context.fetch(expenseDescriptor)) ?? []
        let accountExpenses = allExpenses.filter {
            $0.account?.persistentModelID == selectedAccount.persistentModelID
        }

        let calendar = Calendar.current
        let now = Date()
        let todayInterval = calendar.dateInterval(of: .day, for: now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)

        let today = accountExpenses
            .filter { todayInterval?.contains($0.date) == true && $0.direction == .spent }
            .reduce(0) { $0 + $1.amount }
        let week = accountExpenses
            .filter { weekInterval?.contains($0.date) == true && $0.direction == .spent }
            .reduce(0) { $0 + $1.amount }
        let monthRows = accountExpenses
            .filter { monthInterval?.contains($0.date) == true && $0.direction == .spent }
        let month = monthRows.reduce(0) { $0 + $1.amount }

        let grouped = Dictionary(grouping: monthRows, by: \.category)
        let colors = grouped.compactMap { category, expenses -> (String, Double)? in
            guard let category else { return nil }
            return (category.colorHex, expenses.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.1 > $1.1 }
        .prefix(3)
        .map { Color(hex: $0.0) }

        return WidgetSnapshot(
            accountName: selectedAccount.name,
            today: today,
            week: week,
            month: month,
            colors: colors.isEmpty ? [Color.blue, Color.cyan, Color.indigo] : colors
        )
    }
}

extension Double {
    func currency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >> 8) & 0xff) / 255
        let b = Double(int & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
