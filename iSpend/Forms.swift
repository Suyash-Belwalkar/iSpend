import SwiftData
import SwiftUI

struct AddBankAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let account: BankAccount?
    let existingCount: Int

    @State private var name = ""
    @State private var bankName = ""
    @State private var bankLogoSystemName = "building.columns.fill"
    @State private var ownerName = "Suyash Belwalkar"

    init(account: BankAccount? = nil, existingCount: Int) {
        self.account = account
        self.existingCount = existingCount
        _name = State(initialValue: account?.name ?? "")
        _bankName = State(initialValue: account?.bankName ?? "")
        _bankLogoSystemName = State(initialValue: account?.bankLogoSystemName ?? "building.columns.fill")
        _ownerName = State(initialValue: account?.ownerName ?? "Suyash Belwalkar")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Account name", text: $name)
                    TextField("Bank name", text: $bankName)
                    TextField("Bank logo symbol", text: $bankLogoSystemName)
                    TextField("Owner name", text: $ownerName)
                }

                if account == nil && existingCount >= 4 {
                    Section {
                        Text("You can have a maximum of 4 accounts.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(account == nil ? "Add Account" : "Edit Account")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(account == nil ? "Save" : "Update", action: save)
                        .disabled(existingCount >= 4 && account == nil || name.trimmingCharacters(in: .whitespaces).isEmpty || bankName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if account != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", role: .destructive, action: deleteAccount)
                    }
                }
            }
        }
    }

    private func save() {
        if let account {
            account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            account.bankName = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
            account.bankLogoSystemName = bankLogoSystemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "building.columns.fill" : bankLogoSystemName.trimmingCharacters(in: .whitespacesAndNewlines)
            account.ownerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suyash Belwalkar" : ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            guard existingCount < 4 else { return }
            let account = BankAccount(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
                bankLogoSystemName: bankLogoSystemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "building.columns.fill" : bankLogoSystemName.trimmingCharacters(in: .whitespacesAndNewlines),
                ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Suyash Belwalkar" : ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: existingCount
            )
            modelContext.insert(account)
        }
        WidgetReloader.reload()
        dismiss()
    }

    private func deleteAccount() {
        guard let account else { return }
        modelContext.delete(account)
        WidgetReloader.reload()
        dismiss()
    }
}

struct ExpenseFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    let expense: Expense?
    let account: BankAccount?

    @State private var title = ""
    @State private var amount = 0.0
    @State private var date = Date()
    @State private var direction: ExpenseDirection = .spent
    @State private var parentContext: ExpenseParentContext?
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var note = ""

    init(expense: Expense? = nil, account: BankAccount?) {
        self.expense = expense
        self.account = account
        _title = State(initialValue: expense?.title ?? "")
        _amount = State(initialValue: expense?.amount ?? 0)
        _date = State(initialValue: expense?.date ?? .now)
        _direction = State(initialValue: expense?.direction ?? .spent)
        _parentContext = State(initialValue: expense?.parentContext)
        _selectedCategoryID = State(initialValue: expense?.category?.persistentModelID)
        _note = State(initialValue: expense?.note ?? "")
    }

    private var selectedCategory: ExpenseCategory? {
        if let selectedCategoryID {
            return categories.first(where: { $0.persistentModelID == selectedCategoryID })
        }
        return categories.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Type", selection: $direction) {
                        ForEach(ExpenseDirection.allCases) { direction in
                            Text(direction.rawValue.capitalized).tag(direction)
                        }
                    }
                    Picker("Parent Context", selection: $parentContext) {
                        Text("None").tag(Optional<ExpenseParentContext>.none)
                        ForEach(ExpenseParentContext.allCases) { context in
                            Text(context.title).tag(Optional(context))
                        }
                    }
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(categories) { category in
                            Text(category.name)
                                .tag(Optional(category.persistentModelID))
                        }
                    }
                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(expense == nil ? "Add Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(expense == nil ? "Save" : "Update", action: save)
                        .disabled(account == nil || selectedCategory == nil || title.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
                if expense != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", role: .destructive, action: deleteExpense)
                    }
                }
            }
        }
    }

    private func save() {
        guard let account else { return }

        if let expense {
            expense.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            expense.amount = amount
            expense.date = date
            expense.direction = direction
            expense.parentContext = parentContext
            expense.category = selectedCategory
            expense.note = note
            expense.account = account
        } else {
            let newExpense = Expense(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                date: date,
                direction: direction,
                parentContext: parentContext,
                category: selectedCategory,
                note: note,
                account: account
            )
            modelContext.insert(newExpense)
        }

        WidgetReloader.reload()
        dismiss()
    }

    private func deleteExpense() {
        guard let expense else { return }
        modelContext.delete(expense)
        WidgetReloader.reload()
        dismiss()
    }
}

struct FriendEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var friendName = ""
    @State private var amount = 0.0
    @State private var date = Date()
    @State private var direction: FriendDirection = .owesMe
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Friend Ledger") {
                    TextField("Friend name", text: $friendName)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Direction", selection: $direction) {
                        ForEach(FriendDirection.allCases) { value in
                            Text(value == .owesMe ? "Owes me" : "I owe").tag(value)
                        }
                    }
                    TextField("Note", text: $note)
                }
            }
            .navigationTitle("Add Friend Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(friendName.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            FriendLedgerEntry(
                friendName: friendName.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                date: date,
                direction: direction,
                note: note
            )
        )
        WidgetReloader.reload()
        dismiss()
    }
}

struct InvestmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var amount = 0.0
    @State private var dueDay = 1
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Recurring Investment") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Stepper("Due day: \(dueDay)", value: $dueDay, in: 1 ... 31)
                    TextField("Note", text: $note)
                }
            }
            .navigationTitle("Add Investment")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(
            Investment(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                dueDay: dueDay,
                note: note
            )
        )
        WidgetReloader.reload()
        dismiss()
    }
}

struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var amount = 0.0
    @State private var maxMembers = 6

    var body: some View {
        NavigationStack {
            Form {
                Section("Subscription") {
                    TextField("Title", text: $title)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Stepper("Max members: \(maxMembers)", value: $maxMembers, in: 1 ... 12)
                }
            }
            .navigationTitle("Add Subscription")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount <= 0)
                }
            }
        }
    }

    private func save() {
        let subscription = FamilySubscription(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            maxMembers: maxMembers
        )
        modelContext.insert(subscription)
        WidgetReloader.reload()
        dismiss()
    }
}

struct SubscriptionMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let subscription: FamilySubscription
    let member: SubscriptionMember?

    @State private var memberName = ""
    @State private var amount = 0.0
    @State private var isPaid = true
    @State private var paidThroughMonth = Date()

    init(subscription: FamilySubscription, member: SubscriptionMember? = nil) {
        self.subscription = subscription
        self.member = member
        _memberName = State(initialValue: member?.memberName ?? "")
        _amount = State(initialValue: member?.amount ?? 0)
        _isPaid = State(initialValue: member?.paidThroughMonth != nil)
        _paidThroughMonth = State(initialValue: member?.paidThroughMonth ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(subscription.title) {
                    TextField("Member name", text: $memberName)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Toggle("Marked as paid", isOn: $isPaid)
                    if isPaid {
                        DatePicker("Paid through", selection: $paidThroughMonth, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(member == nil ? "Add Member" : "Edit Member")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(member == nil ? "Save" : "Update", action: save)
                        .disabled(memberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount <= 0)
                }
                if member != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete", role: .destructive, action: deleteMember)
                    }
                }
            }
        }
    }

    private func save() {
        let normalizedMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: paidThroughMonth)
        ) ?? paidThroughMonth

        if let member {
            member.memberName = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
            member.amount = amount
            member.paidThroughMonth = isPaid ? normalizedMonth : nil
            member.subscription = subscription
        } else {
            let newMember = SubscriptionMember(
                memberName: memberName.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                paidThroughMonth: isPaid ? normalizedMonth : nil,
                subscription: subscription
            )
            modelContext.insert(newMember)
        }
        WidgetReloader.reload()
        dismiss()
    }

    private func deleteMember() {
        guard let member else { return }
        modelContext.delete(member)
        WidgetReloader.reload()
        dismiss()
    }
}

struct CategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: ExpenseCategory?

    @State private var name = ""
    @State private var selectedColor: Color = .orange

    init(category: ExpenseCategory? = nil) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _selectedColor = State(initialValue: Color(hex: category?.colorHex ?? "#FF9500"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(category == nil ? "Save" : "Update", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        if let category {
            category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            category.colorHex = selectedColor.hexString
        } else {
            modelContext.insert(
                ExpenseCategory(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    colorHex: selectedColor.hexString
                )
            )
        }
        WidgetReloader.reload()
        dismiss()
    }
}
