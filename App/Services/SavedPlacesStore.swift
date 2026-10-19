import Foundation

// MARK: - Saved places + Home/Work
//
// Saved places live in UserDefaults (JSON). Home/Work are ALSO mirrored
// into the App Group as plain dictionaries — that is exactly what the
// AtlasWidget reads, so the home-screen widget can offer one-tap
// directions without opening the app's data store.

struct SavedPlace: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var place: Place
    var savedAt: Date = Date()
}

@MainActor
final class SavedPlacesStore: ObservableObject {
    @Published var saved: [SavedPlace] = [] { didSet { persist() } }
    @Published var home: Place? { didSet { persistRole(home, key: "atlas.home") } }
    @Published var work: Place? { didSet { persistRole(work, key: "atlas.work") } }

    static let appGroup = "group.com.hggdet.atlas"
    private let savedKey = "atlas.savedPlaces.v1"

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            saved = decoded
        }
        if let data = defaults.data(forKey: "atlas.home"),
           let decoded = try? JSONDecoder().decode(Place.self, from: data) { home = decoded }
        if let data = defaults.data(forKey: "atlas.work"),
           let decoded = try? JSONDecoder().decode(Place.self, from: data) { work = decoded }
        mirrorToWidget()
    }

    func contains(_ place: Place) -> Bool {
        saved.contains { abs($0.place.latitude - place.latitude) < 0.00005
            && abs($0.place.longitude - place.longitude) < 0.00005 }
    }

    @discardableResult
    func toggle(_ place: Place) -> Bool {
        if let idx = saved.firstIndex(where: { abs($0.place.latitude - place.latitude) < 0.00005
            && abs($0.place.longitude - place.longitude) < 0.00005 }) {
            saved.remove(at: idx)
            return false
        }
        saved.insert(SavedPlace(place: place), at: 0)
        return true
    }

    func remove(_ item: SavedPlace) { saved.removeAll { $0.id == item.id } }

    func setHome(_ place: Place?) { home = place }
    func setWork(_ place: Place?) { work = place }

    // MARK: Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: savedKey)
        }
    }

    private func persistRole(_ place: Place?, key: String) {
        if let place, let data = try? JSONEncoder().encode(place) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        mirrorToWidget()
    }

    /// The widget reads `home`/`work` dictionaries {name, lat, lon} from
    /// the shared suite — keep this shape in sync with AtlasWidget.
    private func mirrorToWidget() {
        let shared = UserDefaults(suiteName: Self.appGroup)
        if let home {
            shared?.set(["name": home.name, "lat": home.latitude, "lon": home.longitude],
                        forKey: "home")
        } else { shared?.removeObject(forKey: "home") }
        if let work {
            shared?.set(["name": work.name, "lat": work.latitude, "lon": work.longitude],
                        forKey: "work")
        } else { shared?.removeObject(forKey: "work") }
    }
}
