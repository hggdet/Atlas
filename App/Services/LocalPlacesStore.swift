import Foundation

// MARK: - Local places — «خريطة العراق يبنيها العراقيون»
//
// The core Atlas idea: places people add themselves (a bakery down an
// alley, an unlisted landmark) that global maps don't have.
//
// NOW: everything is stored locally as JSON in Application Support and
// drawn on the map from there.
// LATER: `LocalPlacesSyncing` is the seam for Supabase — the store already
// calls `upload(_:)` for every unsynced place and flips `isSynced` on
// success. The skeleton ships `NoopLocalSync`, so nothing leaves the
// device yet and the UI says so honestly.

protocol LocalPlacesSyncing {
    /// Upload one place; return true when the backend has accepted it.
    func upload(_ place: LocalPlace) async -> Bool
    /// Fetch the shared places near a coordinate (empty in the skeleton).
    func fetchNearby(latitude: Double, longitude: Double) async -> [LocalPlace]
}

/// Skeleton sync: deliberately does nothing. Replaced by a Supabase
/// implementation (REST + anon key, sync-only role per the plan) later.
struct NoopLocalSync: LocalPlacesSyncing {
    func upload(_ place: LocalPlace) async -> Bool { false }
    func fetchNearby(latitude: Double, longitude: Double) async -> [LocalPlace] { [] }
}

@MainActor
final class LocalPlacesStore: ObservableObject {
    @Published var places: [LocalPlace] = [] { didSet { persist() } }

    private let sync: LocalPlacesSyncing
    private let fileURL: URL

    init(sync: LocalPlacesSyncing = NoopLocalSync()) {
        self.sync = sync
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("atlas-local-places.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([LocalPlace].self, from: data) {
            places = decoded
        }
    }

    @discardableResult
    func add(name: String, category: String, note: String,
             latitude: Double, longitude: Double) -> LocalPlace {
        let place = LocalPlace(name: name, category: category, note: note,
                               latitude: latitude, longitude: longitude)
        places.insert(place, at: 0)
        Task { await attemptSync(place) }
        return place
    }

    func remove(_ place: LocalPlace) {
        places.removeAll { $0.id == place.id }
    }

    /// Retry uploading everything still local-only (called when the real
    /// backend lands, and safe to call now — Noop just returns false).
    func syncPending() async {
        for place in places where !place.isSynced {
            await attemptSync(place)
        }
    }

    private func attemptSync(_ place: LocalPlace) async {
        guard await sync.upload(place),
              let idx = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[idx].isSynced = true
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(places) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
