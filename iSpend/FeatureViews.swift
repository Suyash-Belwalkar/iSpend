import SwiftData
import SwiftUI
import UIKit

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
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

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

        let grouped = Dictionary(grouping: monthExpenses) { expense in
            expense.effectiveCategoryName(from: categories) ?? "uncategorized"
        }
        let ranked: [(categoryName: String, total: Double)] = grouped.map { entry in
            let total = entry.value.reduce(0) { partialResult, expense in
                partialResult + expense.amount
            }
            return (categoryName: entry.key, total: total)
        }

        return ranked
            .sorted { lhs, rhs in lhs.total > rhs.total }
            .prefix(3)
            .compactMap { item in
                categories.first(where: { $0.normalizedName == item.categoryName.lowercased() })
            }
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
                .fill(.clear)
                .overlay {
                    AnimatedMeshCardGradient(
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

struct AnimatedMeshCardGradient: View {
    let colors: [Color]

    @State private var isAnimating = false

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

    private var points: [SIMD2<Float>] {
        [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5), SIMD2(isAnimating ? 0.18 : 0.78, 0.5), SIMD2(1.0, isAnimating ? 0.5 : 1.0),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
        ]
    }

    private var meshColors: [Color] {
        [
            palette[0], palette[1], palette[2],
            isAnimating ? palette[1] : palette[0], palette[2], palette[1],
            palette[2], palette[1], palette[0]
        ]
    }

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: points,
            colors: meshColors
        )
        .saturation(1.04)
        .brightness(-0.02)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
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
    let onEditEntry: (FriendLedgerEntry) -> Void

    var groupedEntries: [String: [FriendLedgerEntry]] {
        Dictionary(grouping: entries, by: \.friendName)
    }

    var balances: [FriendBalance] {
        entries.balancesByFriend
    }

    var body: some View {
        List {
            ForEach(balances, id: \.name) { balance in
                if let ledger = groupedEntries[balance.name] {
                    Section {
                        ForEach(ledger) { entry in
                            Button {
                                onEditEntry(entry)
                            } label: {
                                FriendLedgerRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            delete(from: ledger, at: offsets)
                        }
                    } header: {
                        HStack {
                            Text(balance.name)
                            Spacer()
                            if balance.absoluteAmount == 0 {
                                Text("Settled")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                HStack(spacing: 6) {
                                    CurrencyText(amount: balance.absoluteAmount)
                                        .foregroundStyle(balance.direction == .owesMe ? .green : .red)
                                    Text(balance.direction == .owesMe ? "He owes" : "I owe")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(balance.direction == .owesMe ? .green : .red)
                                }
                            }
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

private struct FriendLedgerRow: View {
    let entry: FriendLedgerEntry

    private var title: String {
        if entry.isSettled { return "Paid" }
        return entry.direction == .owesMe ? "Owes me" : "I owe"
    }

    private var amountColor: Color {
        if entry.isSettled { return .secondary }
        return entry.direction == .owesMe ? .green : .red
    }

    private var rowOpacity: Double {
        entry.isSettled ? 0.58 : 1
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !entry.visibleNote.isEmpty {
                    Text(entry.visibleNote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            CurrencyText(amount: entry.amount)
                .foregroundStyle(amountColor)
        }
        .opacity(rowOpacity)
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

    private var parentCategories: [ExpenseCategory] {
        categories.filter(\.isParentCategory)
    }

    private var subcategories: [ExpenseCategory] {
        categories.filter { !$0.isParentCategory }
    }

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

            Section("Parent Categories") {
                ForEach(parentCategories) { category in
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
                        modelContext.delete(parentCategories[index])
                    }
                }

                Button("Add Parent Category", action: onAddCategory)
            }

            Section("Categories") {
                ForEach(subcategories) { category in
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
                        modelContext.delete(subcategories[index])
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
    let onSelectExpense: (Expense) -> Void

    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @State private var selectedCategoryID: PersistentIdentifier?

    private var scopedExpenses: [Expense] {
        expenses
            .filter {
                $0.account?.persistentModelID == account.persistentModelID &&
                $0.direction == .spent
            }
            .sorted { $0.date > $1.date }
    }

    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let grouped = Dictionary(grouping: scopedExpenses) { expense in
            expense.effectiveCategoryName(from: categories) ?? "uncategorized"
        }
        return grouped.compactMap { categoryName, rows in
            guard let category = categories.first(where: { $0.normalizedName == categoryName.lowercased() }) else { return nil }
            return (category, rows.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.total > $1.total }
    }

    private var selectedCategory: ExpenseCategory? {
        guard let selectedCategoryID else { return nil }
        return categoryTotals.first { $0.category.persistentModelID == selectedCategoryID }?.category
    }

    private var filteredExpenses: [Expense] {
        guard let selectedCategoryID else { return scopedExpenses }
        guard let selectedCategory = categories.first(where: { $0.persistentModelID == selectedCategoryID }) else { return scopedExpenses }
        return scopedExpenses.filter {
            $0.effectiveCategoryName(from: categories)?.lowercased() == selectedCategory.normalizedName
        }
    }

    private var groupedExpenses: [(String, [Expense])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let grouped = Dictionary(grouping: filteredExpenses) { expense in
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

    private var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private func percentage(for total: Double) -> Int {
        let grandTotal = categoryTotals.reduce(0) { $0 + $1.total }
        guard grandTotal > 0 else { return 0 }
        return Int((total / grandTotal * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Categories")
                    .font(.largeTitle.bold())
                    .padding(.leading, 16)

                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(categoryTotals, id: \.category.persistentModelID) { item in
                                let isDimmed = selectedCategoryID != nil

                                Button {
                                    withAnimation(.spring(response: 0.62, dampingFraction: 0.92, blendDuration: 0.22)) {
                                        selectedCategoryID = item.category.persistentModelID
                                    }
                                } label: {
                                    InsightCategoryCard(
                                        category: item.category,
                                        total: item.total,
                                        percentage: percentage(for: item.total),
                                        isSelected: false
                                    )
                                    .frame(width: 130, height: 270)
                                    .opacity(isDimmed ? 0 : 1)
                                    .scaleEffect(isDimmed ? 0.995 : 1)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedCategoryID != nil)
                            }
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .scrollClipDisabled()
                    }
                    .scrollDisabled(selectedCategoryID != nil)

                    if let selectedCategory,
                       let selectedItem = categoryTotals.first(where: { $0.category.persistentModelID == selectedCategory.persistentModelID }) {
                        Button {
                            withAnimation(.spring(response: 0.62, dampingFraction: 0.92, blendDuration: 0.22)) {
                                selectedCategoryID = nil
                            }
                        } label: {
                            InsightCategoryCard(
                                category: selectedItem.category,
                                total: selectedItem.total,
                                percentage: percentage(for: selectedItem.total),
                                isSelected: true
                            )
                            .frame(maxWidth: .infinity, minHeight: 270, maxHeight: 270)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .center)),
                                removal: .opacity
                            ))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .zIndex(1)
                    }
                }
                .frame(height: 270)
            }
            .animation(.spring(response: 0.62, dampingFraction: 0.92, blendDuration: 0.22), value: selectedCategoryID)

            List {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Transactions")
                            .font(.title.bold())
                        Spacer()
                        CurrencyText(amount: totalAmount)
                            .font(.title2.bold())
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)

                    Text(selectedCategory?.name ?? "All Categories")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                }

                if groupedExpenses.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Expenses",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Transactions for this category will appear here.")
                        )
                    }
                } else {
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
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
        }
        .background(Color(.systemBackground))
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InsightCategoryCard: View {
    let category: ExpenseCategory
    let total: Double
    let percentage: Int
    let isSelected: Bool

    private var tint: Color {
        Color(hex: category.colorHex)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.95),
                            tint.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.26), radius: isSelected ? 26 : 16, y: 14)

            VStack(alignment: .leading, spacing: 10) {
                Text(category.name)
                    .font(isSelected ? .system(size: 28, weight: .bold, design: .rounded) : .title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("spent \(percentage)%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                if isSelected {
                    CurrencyText(amount: total)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: 0)

                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(isSelected ? .system(size: 34) : .title2)
                        .foregroundStyle(.white.opacity(0.18))
                    Spacer()
                    Capsule()
                        .fill(.white.opacity(0.3))
                        .frame(width: 10, height: isSelected ? 112 : 78)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 270)
        .contentShape(.rect)
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

private extension Color {
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
