import AppIntents
import SwiftUI
import WidgetKit

struct iSpendWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let configuration: SelectAccountIntent
}

struct iSpendWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> iSpendWidgetEntry {
        iSpendWidgetEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                accountName: "Axis",
                today: 430,
                week: 1_280,
                month: 4_620,
                colors: [Color.orange, Color.pink, Color.indigo]
            ),
            configuration: SelectAccountIntent()
        )
    }

    func snapshot(for configuration: SelectAccountIntent, in context: Context) async -> iSpendWidgetEntry {
        let snapshot = await MainActor.run {
            WidgetDataLoader.snapshot(for: configuration)
        }
        return iSpendWidgetEntry(date: .now, snapshot: snapshot, configuration: configuration)
    }

    func timeline(for configuration: SelectAccountIntent, in context: Context) async -> Timeline<iSpendWidgetEntry> {
        let snapshot = await MainActor.run {
            WidgetDataLoader.snapshot(for: configuration)
        }
        let entry = iSpendWidgetEntry(date: .now, snapshot: snapshot, configuration: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct iSpendWidgetEntryView: View {
    let entry: iSpendWidgetProvider.Entry

    private func amountLine(_ amount: Double, size: CGFloat, opacity: Double) -> some View {
        let parts = amount.currencyParts()

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.symbol)
                .font(.system(size: size, weight: .bold, design: .default))
                .fontDesign(.default)
            Text(parts.value)
                .font(.system(size: size, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(opacity))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("iSpend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            

            Spacer(minLength: 0)

            amountLine(entry.snapshot.today, size: 30, opacity: 1)
            amountLine(entry.snapshot.week, size: 22, opacity: 0.72)
            amountLine(entry.snapshot.month, size: 18, opacity: 0.46)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetMeshGradientBackground(colors: entry.snapshot.colors)
        }
    }
}

struct iSpendWidget: Widget {
    let kind = "iSpendWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectAccountIntent.self, provider: iSpendWidgetProvider()) { entry in
            iSpendWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Expense Snapshot")
        .description("Shows today, week, and month expenses for a selected account.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    iSpendWidget()
} timeline: {
    iSpendWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            accountName: "Axis",
            today: 430,
            week: 1_280,
            month: 4_620,
            colors: [Color.orange, Color.pink, Color.indigo]
        ),
        configuration: SelectAccountIntent()
    )
}
