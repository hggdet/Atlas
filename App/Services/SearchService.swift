import Foundation
import CoreLocation

// MARK: - Search
//
// Roles are split on purpose (see research 03):
//  - Photon does search-as-you-type (autocomplete). The public Nominatim
//    usage policy FORBIDS autocomplete, so Nominatim is never called here.
//  - Nominatim is used only for user-triggered detail lookups and reverse
//    geocoding (extratags: phone / website / opening_hours / wikidata).
// Both endpoints live in `Config` so they can be swapped for self-hosted
// instances later without touching call sites — a policy requirement for
// Nominatim and a launch requirement for Photon (its public demo is
// fair-use only, and Arabic needs a dump imported with `-languages ar`).

enum SearchConfig {
    static var photonBase = URL(string: "https://photon.komoot.io")!
    static var nominatimBase = URL(string: "https://nominatim.openstreetmap.org")!
}

@MainActor
final class SearchService: ObservableObject {
    @Published var results: [Place] = []
    @Published var isSearching = false

    private var task: Task<Void, Never>?
    private var cache: [String: [Place]] = [:]

    /// Debounced autocomplete. Minimum 3 characters, cancels the previous
    /// in-flight request, caches per query (Nominatim-style cache discipline
    /// applied to Photon too — it keeps the demo endpoint happy).
    func search(query raw: String, near: CLLocation?) {
        task?.cancel()
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3 else { results = []; isSearching = false; return }
        if let hit = cache[query] { results = hit; return }
        isSearching = true
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms debounce
            guard !Task.isCancelled, let self else { return }
            let found = (try? await self.fetchPhoton(query: query, near: near)) ?? []
            guard !Task.isCancelled else { return }
            self.cache[query] = found
            self.results = found
            self.isSearching = false
        }
    }

    func clear() {
        task?.cancel()
        results = []
        isSearching = false
    }

    // MARK: Photon

    private func fetchPhoton(query: String, near: CLLocation?) async throws -> [Place] {
        var components = URLComponents(url: SearchConfig.photonBase.appendingPathComponent("api"),
                                       resolvingAgainstBaseURL: false)!
        // NO `lang` parameter: verified live 2026-10-13, the public Photon
        // demo supports only default/de/en/fr and answers `lang=ar` with an
        // error payload (no features at all). With the default, names inside
        // Iraq still come back in Arabic because OSM `name` there is Arabic.
        // The self-hosted dump (imported with `-languages ar`) unlocks
        // `lang=ar` later — add it back then, in Config, not here.
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "15"),
        ]
        if let near {
            items.append(URLQueryItem(name: "lat", value: "\(near.coordinate.latitude)"))
            items.append(URLQueryItem(name: "lon", value: "\(near.coordinate.longitude)"))
            items.append(URLQueryItem(name: "zoom", value: "14"))
            items.append(URLQueryItem(name: "location_bias_scale", value: "0.1"))
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.setValue("Atlas-iOS-Skeleton", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(PhotonResponse.self, from: data)
        return decoded.features.compactMap { $0.place }
    }

    // MARK: Nominatim — details & reverse ONLY (never autocomplete)

    /// Rich place card data for one OSM object ("node/12345").
    func fetchDetails(osmRef: String) async throws -> Place? {
        let parts = osmRef.split(separator: "/")
        guard parts.count == 2, let id = Int(parts[1]) else { return nil }
        let prefix: String
        switch parts[0] {
        case "node": prefix = "N"
        case "way": prefix = "W"
        case "relation": prefix = "R"
        default: return nil
        }
        var components = URLComponents(url: SearchConfig.nominatimBase.appendingPathComponent("lookup"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "osm_ids", value: "\(prefix)\(id)"),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "extratags", value: "1"),
            URLQueryItem(name: "namedetails", value: "1"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "accept-language", value: "ar"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Atlas-iOS-Skeleton", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([NominatimPlace].self, from: data)
        return decoded.first?.place
    }
}

// MARK: - Arabic normalisation
//
// The query-side half of the research's normalisation layer: hamzas,
// ة/ه, ى/ي, diacritics/tatweel, Eastern-Arabic digits. The same function
// must run on the index side when Photon is self-hosted.
enum ArabicText {
    static func normalize(_ input: String) -> String {
        var s = input
        let map: [String: String] = [
            "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",
            "ؤ": "و", "ئ": "ي", "ى": "ي", "ة": "ه",
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
        ]
        for (from, to) in map { s = s.replacingOccurrences(of: from, with: to) }
        // Strip diacritics (U+064B–U+0652) and tatweel (U+0640).
        s = s.unicodeScalars.filter { !(0x064B...0x0652).contains($0.value) && $0.value != 0x0640 }
            .map { String($0) }
            .joined()
        return s
    }
}

// MARK: - Wire models

private struct PhotonResponse: Decodable {
    struct Feature: Decodable {
        struct Properties: Decodable {
            var name: String?
            var osm_type: String?
            var osm_id: Int?
            var osm_value: String? // e.g. "city", "restaurant" — Photon's real category field
            var type: String?
            var street: String?
            var district: String?
            var county: String?
            var city: String?
            var state: String?
            var country: String?
        }
        struct Geometry: Decodable { var coordinates: [Double] } // [lon, lat]
        var properties: Properties
        var geometry: Geometry

        var place: Place? {
            guard geometry.coordinates.count == 2 else { return nil }
            let lon = geometry.coordinates[0], lat = geometry.coordinates[1]
            let address = [properties.street, properties.district, properties.county, properties.city, properties.state]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "، ")
            var ref: String?
            if let t = properties.osm_type, let i = properties.osm_id {
                let kind = t == "N" ? "node" : (t == "W" ? "way" : "relation")
                ref = "\(kind)/\(i)"
            }
            return Place.make(name: properties.name ?? address,
                              address: address, lat: lat, lon: lon,
                              osmRef: ref, kind: properties.osm_value ?? properties.type)
        }
    }
    var features: [Feature]
}

private struct NominatimPlace: Decodable {
    var lat: String
    var lon: String
    var display_name: String?
    var name: String?
    var type: String?
    var extratags: [String: String]?

    var place: Place? {
        guard let la = Double(lat), let lo = Double(lon) else { return nil }
        var p = Place.make(name: name ?? display_name ?? "",
                           address: display_name ?? "", lat: la, lon: lo, kind: type)
        p.phone = extratags?["phone"] ?? extratags?["contact:phone"]
        p.website = extratags?["website"] ?? extratags?["contact:website"]
        p.openingHours = extratags?["opening_hours"]
        return p
    }
}
