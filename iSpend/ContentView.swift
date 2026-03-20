import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var quickActionRouter = QuickActionRouter.shared
    @Query(sort: \BankAccount.sortOrder) private var accounts: [BankAccount]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \FriendLedgerEntry.date, order: .reverse) private var friendEntries: [FriendLedgerEntry]
    @Query(sort: \Investment.title) private var investments: [Investment]
    @Query(sort: \FamilySubscription.title) private var subscriptions: [FamilySubscription]
    @Query(sort: \SubscriptionMember.memberName) private var subscriptionMembers: [SubscriptionMember]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @State private var selectedAccountID: PersistentIdentifier?
    @State private var activeSheet: HomeSheet?

    init() {}

    private var selectedAccount: BankAccount? {
        if let selectedAccountID,
           let account = accounts.first(where: { $0.persistentModelID == selectedAccountID }) {
            return account
        }
        return accounts.first
    }

    private var sorted: [BankAccount] {
        accounts.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var friendSummary: FriendSummary {
        friendEntries.summary
    }

    private func parentCategoryColor(for context: ExpenseParentContext) -> Color {
        if let category = categories.first(where: { $0.isParentCategory && $0.normalizedName == context.normalizedName }) {
            return Color(hex: category.colorHex)
        }
        switch context {
        case .family:
            return Color.red
        case .friends:
            return Color.purple
        case .gym:
            return Color.purple
        }
    }

    var body: some View {
        TabView {
            if let a = sorted[safe: 0] { accountTab(for: a) }
            if let a = sorted[safe: 1] { accountTab(for: a) }
            if let a = sorted[safe: 2] { accountTab(for: a) }
            if let a = sorted[safe: 3] { accountTab(for: a) }
        }
        .fontDesign(.rounded)
        .task {
            seedDataIfNeeded()
            if selectedAccountID == nil {
                selectedAccountID = accounts.first?.persistentModelID
            }
            handleQuickActionIfNeeded()
        }
        .onChange(of: accounts.count) { _, _ in
            if selectedAccount == nil {
                selectedAccountID = accounts.first?.persistentModelID
            }
            handleQuickActionIfNeeded()
        }
        .onChange(of: quickActionRouter.pendingAction) { _, _ in
            handleQuickActionIfNeeded()
        }
        .onOpenURL { url in
            guard let action = AppDeepLink.action(for: url) else { return }
            quickActionRouter.trigger(action)
        }
    }

    // MARK: - Account Tab

    @TabContentBuilder<Never>
    private func accountTab(for account: BankAccount) -> some TabContent<Never> {
        Tab(account.name, systemImage: "creditcard"){
            NavigationStack {
                dashboardContent(for: account)
                    .navigationTitle("iSpend")
                    .fontDesign(.rounded)
                    // Float the liquid glass Add button just above the tab bar
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        addExpenseButton
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                SettingsView(
                                    onAddAccount: { activeSheet = .addAccount },
                                    onEditAccount: { activeSheet = .editAccount($0) },
                                    onAddCategory: { activeSheet = .addCategory },
                                    onEditCategory: { activeSheet = .editCategory($0) }
                                )
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                    .sheet(item: $activeSheet) { sheet in
                        sheetContent(for: sheet)
                    }
            }
        }
    }

    // MARK: - Liquid Glass Add Button

    private var addExpenseButton: some View {
        HStack {
            Spacer()
            Button {
                activeSheet = .addExpense
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                    Text("Add Expense")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            Spacer()
        }
        .padding(.bottom, 12)
    }

    private func handleQuickActionIfNeeded() {
        guard quickActionRouter.consume() == .addExpense else { return }
        activeSheet = .addExpense
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: HomeSheet) -> some View {
        switch sheet {
        case .addAccount:
            AddBankAccountSheet(existingCount: accounts.count)
        case let .editAccount(account):
            AddBankAccountSheet(account: account, existingCount: accounts.count)
        case .addExpense:
            ExpenseFormSheet(account: selectedAccount)
        case let .editExpense(expense):
            ExpenseFormSheet(expense: expense, account: expense.account ?? selectedAccount)
        case .addInvestment:
            InvestmentSheet()
        case .addFriendEntry:
            FriendEntrySheet()
        case let .editFriendEntry(entry):
            FriendEntrySheet(entry: entry)
        case .addSubscription:
            SubscriptionSheet()
        case let .addSubscriptionMember(subscription):
            SubscriptionMemberSheet(subscription: subscription)
        case let .editSubscriptionMember(member):
            SubscriptionMemberSheet(subscription: member.subscription!, member: member)
        case .addCategory:
            CategorySheet()
        case let .editCategory(category):
            CategorySheet(category: category)
        }
    }

    // MARK: - Dashboard

    @ViewBuilder
    private func dashboardContent(for account: BankAccount) -> some View {
        let scopedExpenses = expenses.filter { $0.account?.persistentModelID == account.persistentModelID }
        let todayRows = scopedExpenses.filter { Calendar.current.isDateInToday($0.date) }
        let totals = expenses.totals(for: account)
        let yearlyTotals = expenses.yearlyTotals(for: account)
        let familyTotal = parentContextMonthTotal(.family, account: account)
        let friendsTotal = parentContextMonthTotal(.friends, account: account)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink {
                    BankInsightsView(
                        account: account,
                        expenses: expenses,
                        onSelectExpense: { activeSheet = .editExpense($0) }
                    )
                } label: {
                    BankCardView(account: account, expenses: expenses)
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        NavigationLink {
                            DailyBreakdownView(totals: yearlyTotals)
                        } label: {
                            ExpenseSummaryCard(totals: totals)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExpensesByDateView(
                                title: "Family",
                                expenses: filteredExpenses(for: .family, account: account),
                                onSelectExpense: { activeSheet = .editExpense($0) }
                            )
                        } label: {
                            ParentContextExpenseCard(title: "Family", amount: familyTotal, tint: parentCategoryColor(for: .family))
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            ExpensesByDateView(
                                title: "Friends",
                                expenses: filteredExpenses(for: .friends, account: account),
                                onSelectExpense: { activeSheet = .editExpense($0) }
                            )
                        } label: {
                            ParentContextExpenseCard(title: "Friends", amount: friendsTotal, tint: parentCategoryColor(for: .friends))
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            FamilySubscriptionsView(
                                onAddSubscription: {
                                    activeSheet = .addSubscription
                                },
                                onAddMember: { subscription in
                                    activeSheet = .addSubscriptionMember(subscription)
                                },
                                onEditMember: { member in
                                    activeSheet = .editSubscriptionMember(member)
                                }
                            )
                        } label: {
                            FamilySubscriptionCard(subscriptions: subscriptions, members: subscriptionMembers)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            InvestmentsView { activeSheet = .addInvestment }
                        } label: {
                            InvestmentsCard(
                                count: investments.count,
                                total: investments.reduce(0) { $0 + $1.amount }
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            FriendsView(
                                onAdd: { activeSheet = .addFriendEntry },
                                onEditEntry: { activeSheet = .editFriendEntry($0) }
                            )
                        } label: {
                            FriendsOverviewCard(summary: friendSummary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollClipDisabled()
                .scrollIndicators(.hidden)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Latest Expenses")
                            .font(.title3.bold())
                        Spacer()
                        NavigationLink {
                            ExpensesByDateView(
                                title: "All Expenses",
                                expenses: scopedExpenses,
                                onSelectExpense: { activeSheet = .editExpense($0) }
                            )
                        } label: {
                            Text("All Expenses")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }

                    if todayRows.isEmpty {
                        ContentUnavailableView(
                            "No Expenses Today",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Today's expenses will appear here.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(todayRows.prefix(12)) { expense in
                                Button {
                                    activeSheet = .editExpense(expense)
                                } label: {
                                    ExpenseRowView(expense: expense)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)

                                if expense.persistentModelID != todayRows.prefix(12).last?.persistentModelID {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Helpers

    private func filteredExpenses(for context: ExpenseParentContext, account: BankAccount? = nil) -> [Expense] {
        let base = account != nil
            ? expenses.filter { $0.account?.persistentModelID == account!.persistentModelID }
            : expenses
        return base.filter { $0.parentContext == context }
    }

    private func parentContextMonthTotal(_ context: ExpenseParentContext, account: BankAccount? = nil) -> Double {
        filteredExpenses(for: context, account: account)
            .filter {
                Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) &&
                $0.direction == .spent
            }
            .reduce(0) { $0 + $1.amount }
    }

    private func seedDataIfNeeded() {
        var didMutateSharedData = false

        let defaultCategories: [(name: String, colorHex: String, isParent: Bool)] = [
            ("Family", "#FF3B30", true),
            ("Friends", "#AF52DE", true),
            ("Gym", "#AF52DE", true),
            ("Food", "#FF9500", false),
            ("Sports", "#34C759", false),
            ("Shopping", "#FF2D55", false),
            ("Subscription", "#007AFF", false),
        ]

        if let turfCategory = categories.first(where: { $0.normalizedName == "turf" }) {
            if turfCategory.name != "Sports" {
                turfCategory.name = "Sports"
                didMutateSharedData = true
            }
            if turfCategory.colorHex != "#34C759" {
                turfCategory.colorHex = "#34C759"
                didMutateSharedData = true
            }
            if turfCategory.isParentCategory {
                turfCategory.isParentCategory = false
                didMutateSharedData = true
            }
        }

        if let dietCategory = categories.first(where: { $0.normalizedName == "diet" }) {
            modelContext.delete(dietCategory)
            didMutateSharedData = true
        }

        for category in categories where ["family", "friends", "gym"].contains(category.normalizedName) && !category.isParentCategory {
            category.isParentCategory = true
            didMutateSharedData = true
        }

        for (name, colorHex, isParent) in defaultCategories {
            if let existingCategory = categories.first(where: { $0.normalizedName == name.lowercased() }) {
                if existingCategory.isParentCategory != isParent {
                    existingCategory.isParentCategory = isParent
                    didMutateSharedData = true
                }
                if existingCategory.name != name {
                    existingCategory.name = name
                    didMutateSharedData = true
                }
            } else {
                modelContext.insert(ExpenseCategory(name: name, colorHex: colorHex, isParentCategory: isParent))
                didMutateSharedData = true
            }
        }

        if accounts.isEmpty {
            let primary = BankAccount(name: "Axis", bankName: "Axis Bank", bankLogoSystemName: "building.columns.fill", sortOrder: 0)
            let secondary = BankAccount(name: "Union", bankName: "Union Bank", bankLogoSystemName: "building.columns.circle.fill", sortOrder: 1)
            modelContext.insert(primary)
            modelContext.insert(secondary)
            selectedAccountID = primary.persistentModelID
            didMutateSharedData = true
        }

        if subscriptions.isEmpty {
            modelContext.insert(FamilySubscription(title: "Apple Music Family", amount: 149, maxMembers: 6))
            didMutateSharedData = true
        }

        if didMutateSharedData {
            WidgetReloader.reload()
        }
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let schema = Schema([
        BankAccount.self,
        Expense.self,
        FriendLedgerEntry.self,
        Investment.self,
        FamilySubscription.self,
        SubscriptionMember.self,
        ExpenseCategory.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return ContentView()
        .modelContainer(container)
}
