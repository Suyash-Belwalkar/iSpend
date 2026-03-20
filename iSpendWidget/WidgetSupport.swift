import AppIntents
import Foundation
import SwiftData
import SwiftUI
import UIKit

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
        let categoryDescriptor = FetchDescriptor<ExpenseCategory>()
        let allCategories = (try? context.fetch(categoryDescriptor)) ?? []
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

        let grouped = Dictionary(grouping: monthRows) { expense in
            expense.effectiveCategoryColorHex(from: allCategories) ?? ""
        }
        let colors = grouped.compactMap { colorHex, expenses -> (String, Double)? in
            guard !colorHex.isEmpty else { return nil }
            return (colorHex, expenses.reduce(0) { $0 + $1.amount })
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

    func currencyParts() -> (symbol: String, value: String) {
        let formatted = currency()
        let symbol = "₹"
        if formatted.hasPrefix(symbol) {
            return (symbol, String(formatted.dropFirst(symbol.count)))
        }
        return (symbol, formatted)
    }
}

struct WidgetMeshGradientBackground: View {
    let colors: [Color]

    private var palette: [Color] {
        let fallback = [Color.blue, Color.cyan, Color.indigo]
        let resolved = colors.isEmpty ? fallback : colors

        if resolved.count >= 3 {
            return Array(resolved.prefix(3))
        }

        if resolved.count == 2 {
            return [resolved[0], resolved[1], resolved[0].mix(with: resolved[1], amount: 0.45)]
        }

        return [resolved[0], resolved[0].opacity(0.92), resolved[0].opacity(0.8)]
    }

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                SIMD2(0.0, 0.5), SIMD2(0.56, 0.5), SIMD2(1.0, 0.62),
                SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
            ],
            colors: [
                palette[0], palette[1], palette[2],
                palette[0], palette[2], palette[1],
                palette[2], palette[1], palette[0]
            ]
        )
        .saturation(1.08)
        .brightness(-0.03)
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

    func mix(with other: Color, amount: Double) -> Color {
        let fraction = min(max(amount, 0), 1)
        return Color(
            UIColor(self).mixed(with: UIColor(other), amount: fraction)
        )
    }
}

private extension UIColor {
    func mixed(with other: UIColor, amount: Double) -> UIColor {
        let fraction = CGFloat(min(max(amount, 0), 1))

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1 + (a2 - a1) * fraction
        )
    }
}
