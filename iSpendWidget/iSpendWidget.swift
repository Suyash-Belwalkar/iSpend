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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("iSpend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            

            Spacer(minLength: 0)

            Text(entry.snapshot.today.currency())
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.snapshot.week.currency())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.snapshot.month.currency())
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(
            LinearGradient(
                colors: entry.snapshot.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
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
