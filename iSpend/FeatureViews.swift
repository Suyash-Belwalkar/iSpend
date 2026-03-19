import SwiftData
import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(expense.title)
                Text(rowSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                CurrencyText(amount: expense.amount)
                    .foregroundStyle(expense.direction.tint)
                Text(expense.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rowSubtitle: String {
        let parts = [expense.parentContext?.title, expense.category?.name].compactMap { $0 }
        return parts.isEmpty ? "Uncategorized" : parts.joined(separator: " • ")
    }
}

struct DailyBreakdownView: View {
    let totals: YearlyExpenseTotals

    var body: some View {
        List {
            Section("Current Period") {
                LabeledContent("Today") { CurrencyText(amount: totals.today) }
                LabeledContent("This Week") { CurrencyText(amount: totals.week) }
                LabeledContent("This Month") { CurrencyText(amount: totals.month) }
                LabeledContent("This Year") { CurrencyText(amount: totals.year) }
            }
        }
        .navigationTitle("Expense Summary")
    }
}

struct BankCardView: View {
    let account: BankAccount
    let expenses: [Expense]

    var balance: Double {
        expenses
            .filter { $0.account?.persistentModelID == account.persistentModelID }
            .netTotal
    }

    var prominentCategories: [ExpenseCategory] {
        let monthExpenses = expenses.filter {
            $0.account?.persistentModelID == account.persistentModelID &&
            Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) &&
            $0.direction == .spent
        }

        let grouped = Dictionary(grouping: monthExpenses, by: \.category)
        let ranked: [(category: ExpenseCategory, total: Double)] = grouped.compactMap { entry in
            guard let category = entry.key else { return nil }
            let total = entry.value.reduce(0) { partialResult, expense in
                partialResult + expense.amount
            }
            return (category: category, total: total)
        }

        return ranked
            .sorted { lhs, rhs in lhs.total > rhs.total }
            .prefix(3)
            .map(\.category)
    }

    var palette: [Color] {
        let colors = prominentCategories.map { Color(hex: $0.colorHex) }
        return colors.isEmpty ? [Color.blue, Color.cyan, Color.indigo] : colors
    }

    var gradient: LinearGradient {
        LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(gradient)
                .overlay {
                    AnimatedCardGradient(
                        colors: palette
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: account.bankLogoSystemName)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Text(account.name)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.95))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    CurrencyText(amount: balance)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prominentCategories.isEmpty ? "No spend data yet" : prominentCategories.map(\.name).joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(account.ownerName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(22)
        }
        .frame(height: 220)
    }
}

struct AnimatedCardGradient: View {
    let colors: [Color]

    @State private var phaseOne = false
    @State private var phaseTwo = false
    @State private var phaseThree = false

    private var palette: [Color] {
        colors.isEmpty ? [Color.blue, Color.cyan, Color.indigo] : colors
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                animatedBlob(
                    color: palette[0].opacity(0.16),
                    size: proxy.size.width * 0.78,
                    x: phaseOne ? proxy.size.width * 0.76 : proxy.size.width * 0.2,
                    y: phaseOne ? proxy.size.height * 0.26 : proxy.size.height * 0.78,
                    animationValue: phaseOne,
                    duration: 9.5
                )

                animatedBlob(
                    color: (palette.count > 1 ? palette[1] : palette[0]).opacity(0.14),
                    size: proxy.size.width * 0.72,
                    x: phaseTwo ? proxy.size.width * 0.28 : proxy.size.width * 0.84,
                    y: phaseTwo ? proxy.size.height * 0.2 : proxy.size.height * 0.68,
                    animationValue: phaseTwo,
                    duration: 12
                )

                animatedBlob(
                    color: (palette.count > 2 ? palette[2] : palette[0]).opacity(0.12),
                    size: proxy.size.width * 0.68,
                    x: phaseThree ? proxy.size.width * 0.62 : proxy.size.width * 0.12,
                    y: phaseThree ? proxy.size.height * 0.84 : proxy.size.height * 0.18,
                    animationValue: phaseThree,
                    duration: 10.5
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .blendMode(.softLight)
        .opacity(0.65)
        .onAppear {
            phaseOne = true
            phaseTwo = true
            phaseThree = true
        }
    }

    private func animatedBlob(color: Color, size: CGFloat, x: CGFloat, y: CGFloat, animationValue: Bool, duration: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 34)
            .position(x: x, y: y)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: animationValue)
    }
}

struct ExpenseSummaryCard: View {
    let totals: ExpenseTotals

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Expenses")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                CurrencyText(amount: totals.today)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 6) {
                    CurrencyText(amount: totals.week)
                        .font(.title2.bold())
                        .foregroundStyle(.primary.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    CurrencyText(amount: totals.month)
                        .font(.title3.bold())
                        .foregroundStyle(.primary.opacity(0.38))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ParentContextExpenseCard: View {
    let title: String
    let amount: Double
    let tint: Color

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.title3.bold())
                    Spacer()
                }

                Spacer()

                CurrencyText(amount: amount)
                    .font(.title2.bold())
                    .foregroundStyle(tint)
            }
        }
    }
}

struct FriendsOverviewCard: View {
    let summary: FriendSummary

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Ledger")
                        .font(.title3.bold())
                    Spacer()
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        CurrencyText(amount: summary.owedToMe)
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                        Text("Owe Me")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        CurrencyText(amount: summary.iOwe)
                            .font(.title3.bold())
                            .foregroundStyle(.red)
                        Text("I Owe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: -10) {
                    ForEach(Array(summary.names.prefix(4)), id: \.self) { name in
                        Circle()
                            .fill(Color.white)
                            .overlay {
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(.black.opacity(0.8))
                            }
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 1))
                    }

                    if summary.names.isEmpty {
                        Text("No entries yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

struct ExpensesByDateView: View {
    let title: String
    let expenses: [Expense]
    let onSelectExpense: (Expense) -> Void

    private var groupedExpenses: [(String, [Expense])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: expenses) { expense in
            formatter.string(from: expense.date)
        }

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            guard
                let leftDate = formatter.date(from: lhs),
                let rightDate = formatter.date(from: rhs)
            else {
                return lhs > rhs
            }
            return leftDate > rightDate
        }

        return sortedKeys.map { key in
            let values = (grouped[key] ?? []).sorted { $0.date > $1.date }
            return (key, values)
        }
    }

    var body: some View {
        List {
            ForEach(groupedExpenses, id: \.0) { sectionTitle, rows in
                Section(sectionTitle) {
                    ForEach(rows) { expense in
                        Button {
                            onSelectExpense(expense)
                        } label: {
                            ExpenseRowView(expense: expense)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

struct InvestmentsCard: View {
    let count: Int
    let total: Double

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Investments")
                        .font(.title3.bold())
                    Spacer()
                }
                Spacer()
                CurrencyText(amount: total)
                    .font(.title2.bold())
                Text("\(count) monthly recurring payments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FamilySubscriptionCard: View {
    let subscriptions: [FamilySubscription]
    let members: [SubscriptionMember]

    var body: some View {
        let paidCount = members.filter(\.isCurrentMonthPaid).count

        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Subscriptions")
                        .font(.title3.bold())
                    Spacer()
                }

                Spacer()

                Text("\(subscriptions.count) active plan\(subscriptions.count == 1 ? "" : "s")")
                    .font(.title3.bold())
                Text("\(paidCount) members marked paid for this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(content.padding(18))
            .frame(width: 220, height: 190)
    }
}

struct InvestmentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Investment.title) private var investments: [Investment]

    let onAdd: () -> Void

    var body: some View {
        List {
            if investments.isEmpty {
                ContentUnavailableView("No Investments", systemImage: "chart.line.uptrend.xyaxis", description: Text("Add monthly recurring investments to track them here."))
            } else {
                ForEach(investments) { investment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(investment.title)
                            Spacer()
                            CurrencyText(amount: investment.amount)
                                .foregroundStyle(.primary)
                        }
                        Text("Due every month on day \(investment.dueDay)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !investment.note.isEmpty {
                            Text(investment.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Investments")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(investments[index])
        }
    }
}

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FriendLedgerEntry.date, order: .reverse) private var entries: [FriendLedgerEntry]

    let onAdd: () -> Void

    var groupedEntries: [String: [FriendLedgerEntry]] {
        Dictionary(grouping: entries, by: \.friendName)
    }

    var body: some View {
        List {
            ForEach(groupedEntries.keys.sorted(), id: \.self) { name in
                if let ledger = groupedEntries[name] {
                    Section(name) {
                        ForEach(ledger) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.direction == .owesMe ? "Owes me" : "I owe")
                                    Text(entry.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                CurrencyText(amount: entry.amount)
                                    .foregroundStyle(entry.direction == .owesMe ? .green : .red)
                            }
                        }
                        .onDelete { offsets in
                            delete(from: ledger, at: offsets)
                        }
                    }
                }
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func delete(from ledger: [FriendLedgerEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(ledger[index])
        }
    }
}

struct FamilySubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FamilySubscription.title) private var subscriptions: [FamilySubscription]
    @Query(sort: \SubscriptionMember.memberName) private var members: [SubscriptionMember]

    let onAddSubscription: () -> Void
    let onAddMember: (FamilySubscription) -> Void
    let onEditMember: (SubscriptionMember) -> Void

    var body: some View {
        List {
            if subscriptions.isEmpty {
                ContentUnavailableView("No Subscriptions", systemImage: "person.3.sequence.fill", description: Text("A default Apple Music family plan will appear once the app seeds data."))
            } else {
                ForEach(subscriptions) { subscription in
                    Section {
                        let rows = members.filter { $0.subscription?.persistentModelID == subscription.persistentModelID }

                        ForEach(rows) { member in
                            Button {
                                onEditMember(member)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(member.memberName)
                                        Spacer()
                                        CurrencyText(amount: member.amount)
                                            .foregroundStyle(member.isCurrentMonthPaid ? .green : .red)
                                    }
                                    Text(member.paidThroughLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            delete(rows: rows, offsets: offsets)
                        }

                        Button("Add Member") {
                            onAddMember(subscription)
                        }
                    } header: {
                        Text(subscription.title)
                    } footer: {
                        Text("Tracks each member and the month till which they have paid.")
                    }
                }
            }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddSubscription) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func delete(rows: [SubscriptionMember], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rows[index])
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BankAccount.sortOrder) private var accounts: [BankAccount]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    let onAddAccount: () -> Void
    let onEditAccount: (BankAccount) -> Void
    let onAddCategory: () -> Void
    let onEditCategory: (ExpenseCategory) -> Void

    var body: some View {
        List {
            Section("Accounts") {
                ForEach(accounts) { account in
                    Button {
                        onEditAccount(account)
                    } label: {
                        HStack {
                            Label(account.name, systemImage: account.bankLogoSystemName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(account.bankName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button("Add Account", action: onAddAccount)
                    .disabled(accounts.count >= 4)

                if accounts.count >= 4 {
                    Text("Maximum 4 accounts reached.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Categories") {
                ForEach(categories) { category in
                    Button {
                        onEditCategory(category)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: category.colorHex))
                                .frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(category.name)
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(categories[index])
                    }
                }

                Button("Add Category", action: onAddCategory)
            }
        }
        .navigationTitle("Settings")
    }
}

struct BankInsightsView: View {
    let account: BankAccount
    let expenses: [Expense]

    var categoryTotals: [(ExpenseCategory, Double)] {
        let scoped = expenses.filter {
            $0.account?.persistentModelID == account.persistentModelID && $0.direction == .spent
        }
        let grouped = Dictionary(grouping: scoped, by: \.category)
        return grouped.compactMap { category, rows in
            guard let category else { return nil }
            return (category, rows.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        List {
            Section("Category Distribution") {
                ForEach(categoryTotals, id: \.0.persistentModelID) { category, total in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(category.name, systemImage: "circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color(hex: category.colorHex), Color(hex: category.colorHex))
                            Spacer()
                            CurrencyText(amount: total)
                                .font(.headline)
                        }

                        GeometryReader { proxy in
                            let maxValue = categoryTotals.first?.1 ?? 1
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(hex: category.colorHex).opacity(0.2))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(hex: category.colorHex))
                                        .frame(width: max(proxy.size.width * (total / maxValue), 10))
                                }
                        }
                        .frame(height: 12)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(account.name)
    }
}

struct AccountTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .glassEffect(.regular.interactive())
                    }
                }
        }
        .contentShape(.capsule)
    }
}
