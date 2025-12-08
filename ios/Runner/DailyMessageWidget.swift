import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), message: "Tu esi nuostabus! ❤️", writer: "Tavo mylimas")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), message: "Tu esi nuostabus! ❤️", writer: "Tavo mylimas")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        
        // Gauti duomenis iš UserDefaults
        let userDefaults = UserDefaults(suiteName: "group.lockscreenlove")
        let message = userDefaults?.string(forKey: "daily_message") ?? "Tu esi nuostabus! ❤️"
        let writer = userDefaults?.string(forKey: "writer_name") ?? "Tavo mylimas"
        
        // Sukurti entry
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, message: message, writer: writer)
        entries.append(entry)
        
        // Atnaujinti kitą dieną
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let message: String
    let writer: String
}

struct DailyMessageWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("❤️ Dienos žinutė")
                .font(.system(size: 12))
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Text(entry.message)
                .font(.system(size: 14))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            if !entry.writer.isEmpty {
                Text(entry.writer)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

struct DailyMessageWidget: Widget {
    let kind: String = "DailyMessageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DailyMessageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dienos žinutė")
        .description("Rodykite kasdieninę žinutę iš savo antrosios pusės")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyMessageWidget_Previews: PreviewProvider {
    static var previews: some View {
        DailyMessageWidgetEntryView(entry: SimpleEntry(
            date: Date(),
            message: "Tu esi geriausias! Kiekviena diena su tavimi yra dovana",
            writer: "Tavo mylimas"
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}