import SwiftUI

// MARK: - Saved places sheet (home / work / saved list)

struct SavedPlacesView: View {
    var onPick: (Place) -> Void

    @EnvironmentObject private var saved: SavedPlacesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("أماكني".loc).font(.title3.weight(.black))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
            }

            if let home = saved.home {
                row(icon: "house.fill", title: "البيت".loc, place: home)
            }
            if let work = saved.work {
                row(icon: "briefcase.fill", title: "الشغل".loc, place: work)
            }

            if saved.saved.isEmpty && saved.home == nil && saved.work == nil {
                Text("لا توجد أماكن محفوظة بعد").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(saved.saved) { item in
                    HStack(spacing: 8) {
                        row(icon: "bookmark.fill", title: item.place.name, place: item.place)
                        Button(role: .destructive) { saved.remove(item) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func row(icon: String, title: String, place: Place) -> some View {
        Button { onPick(place) } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(adaptiveInk)
                    if !place.address.isEmpty {
                        Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.left").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
