import WidgetKit
import SwiftUI

// Home-screen widget (skeleton): one-tap shortcuts to Home / Work.
// Reads the plain {name, lat, lon} dictionaries SavedPlacesStore mirrors
// into the App Group, and deep-links atlas://home / atlas://work,
// which ContentView turns into a directions sheet.

struct QuickEntry: TimelineEntry {
    let date: Date
    let homeName: String?
    let workName: String?
}

struct QuickProvider: TimelineProvider {
    private func read() -> (String?, String?) {
        let shared = UserDefaults(suiteName: "group.com.hggdet.atlas")
        let home = shared?.dictionary(forKey: "home")?["name"] as? String
        let work = shared?.dictionary(forKey: "work")?["name"] as? String
        return (home, work)
    }
    func placeholder(in context: Context) -> QuickEntry {
        QuickEntry(date: Date(), homeName: "البيت", workName: "الشغل")
    }
    func getSnapshot(in context: Context, completion: @escaping (QuickEntry) -> Void) {
        let (h, w) = read()
        completion(QuickEntry(date: Date(), homeName: h, workName: w))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) {
        let (h, w) = read()
        let entry = QuickEntry(date: Date(), homeName: h, workName: w)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickWidgetView: View {
    var entry: QuickEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("اطلس").font(.caption.weight(.black)).foregroundStyle(.secondary)
            if entry.homeName == nil && entry.workName == nil {
                Text("عيّن البيت والشغل من داخل التطبيق حتى تصلهم من هنا بضغطة.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let home = entry.homeName {
                Link(destination: URL(string: "atlas://home")!) {
                    Label(home, systemImage: "house.fill").font(.subheadline.weight(.bold))
                }
            }
            if let work = entry.workName {
                Link(destination: URL(string: "atlas://work")!) {
                    Label(work, systemImage: "briefcase.fill").font(.subheadline.weight(.bold))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }
}

@main
struct AtlasWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AtlasQuick", provider: QuickProvider()) { entry in
            QuickWidgetView(entry: entry)
        }
        .configurationDisplayName("اطلس سريع")
        .description("طريق مختصر إلى البيت والشغل")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
