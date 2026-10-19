import SwiftUI

// MARK: - Place card (bottom-sheet content)
//
// Skeleton card: name, address line, distance, and the actions the
// skeleton actually supports — directions, save, set as home/work,
// share, call/website when Nominatim details provided them.
// ("Open now" evaluation and Wikidata photos are a later enrichment
// phase — see research 03 — and are NOT faked here.)

struct PlaceCardView: View {
    var place: Place
    var onDirections: () -> Void

    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var saved: SavedPlacesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.title3.weight(.black)).lineLimit(2)
                    if !place.address.isEmpty {
                        Text(place.address).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if let metres = place.distance(from: location.location) {
                        Text(Format.distance(metres)).font(.footnote.weight(.semibold))
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    onDirections()
                } label: {
                    Label("الاتجاهات".loc, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    saved.toggle(place)
                } label: {
                    Label(saved.contains(place) ? "محفوظ".loc : "حفظ".loc,
                          systemImage: saved.contains(place) ? "bookmark.fill" : "bookmark")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
            }

            if let phone = place.phone, let url = URL(string: "tel://\(phone)") {
                Link(destination: url) {
                    Label(phone, systemImage: "phone.fill").font(.subheadline.weight(.semibold))
                }
            }
            if let website = place.website, let url = URL(string: website) {
                Link(destination: url) {
                    Label(website, systemImage: "globe").font(.subheadline.weight(.semibold)).lineLimit(1)
                }
            }
            if let hours = place.openingHours {
                Label(hours, systemImage: "clock").font(.footnote).foregroundStyle(.secondary)
            }

            Menu {
                Button { saved.setHome(place) } label: { Label("البيت".loc, systemImage: "house.fill") }
                Button { saved.setWork(place) } label: { Label("الشغل".loc, systemImage: "briefcase.fill") }
            } label: {
                Label("تعيين كـ بيت / شغل", systemImage: "star").font(.subheadline.weight(.semibold))
            }

            ShareLink(item: "\(place.name)\nhttps://maps.apple.com/?ll=\(place.latitude),\(place.longitude)") {
                Label("مشاركة".loc, systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
