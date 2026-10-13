import Foundation
import CoreLocation

// MARK: - Place (from Photon / Nominatim / a local contribution)

struct Place: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// Secondary line: street / neighbourhood / city, as the source gives it.
    var address: String
    var latitude: Double
    var longitude: Double
    /// OSM identity, e.g. "node/12345" — used to fetch Nominatim details.
    var osmRef: String?
    var kind: String?
    var phone: String?
    var website: String?
    var openingHours: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func make(name: String, address: String, lat: Double, lon: Double,
                     osmRef: String? = nil, kind: String? = nil) -> Place {
        Place(id: osmRef ?? "\(lat),\(lon)-\(name)", name: name, address: address,
              latitude: lat, longitude: lon, osmRef: osmRef, kind: kind)
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        guard let location else { return nil }
        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }
}

// MARK: - Route (from Valhalla)

enum TravelMode: String, CaseIterable, Identifiable {
    case driving, walking, cycling
    var id: String { rawValue }

    /// Valhalla costing name.
    var costing: String {
        switch self {
        case .driving: return "auto"
        case .walking: return "pedestrian"
        case .cycling: return "bicycle"
        }
    }
    var icon: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }
    var label: String {
        switch self {
        case .driving: return "سيارة".loc
        case .walking: return "مشي".loc
        case .cycling: return "دراجة".loc
        }
    }
}

struct RouteStep: Identifiable, Equatable {
    var id = UUID()
    var instruction: String
    var distance: Double // metres
    var coordinate: CLLocationCoordinate2D
    static func == (lhs: RouteStep, rhs: RouteStep) -> Bool { lhs.id == rhs.id }
}

struct RouteData: Identifiable, Equatable {
    var id = UUID()
    var distance: Double // metres
    var duration: Double // seconds
    var coordinates: [CLLocationCoordinate2D]
    var steps: [RouteStep]
    static func == (lhs: RouteData, rhs: RouteData) -> Bool { lhs.id == rhs.id }
}

// MARK: - Local place (user-contributed — the core Atlas idea)

struct LocalPlace: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var category: String
    var note: String = ""
    var latitude: Double
    var longitude: Double
    var createdAt: Date = Date()
    /// false while it only lives on this device; the Supabase sync layer
    /// (LocalPlacesSyncing) flips it once the place is uploaded.
    var isSynced: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var asPlace: Place {
        Place(id: "local-\(id.uuidString)", name: name, address: category,
              latitude: latitude, longitude: longitude, kind: category)
    }
}

// MARK: - Offline province catalogue

struct Province: Identifiable, Equatable {
    var id: String
    var name: String
    var sw: CLLocationCoordinate2D
    var ne: CLLocationCoordinate2D
    static func == (lhs: Province, rhs: Province) -> Bool { lhs.id == rhs.id }

    /// Starter catalogue. Bounds are rough city envelopes (zoom-capped
    /// downloads in OfflineService keep the packs sane in size).
    static let catalogue: [Province] = [
        Province(id: "baghdad", name: "بغداد",
                 sw: CLLocationCoordinate2D(latitude: 33.18, longitude: 44.18),
                 ne: CLLocationCoordinate2D(latitude: 33.46, longitude: 44.66)),
        Province(id: "erbil", name: "أربيل",
                 sw: CLLocationCoordinate2D(latitude: 36.05, longitude: 43.90),
                 ne: CLLocationCoordinate2D(latitude: 36.32, longitude: 44.16)),
        Province(id: "basra", name: "البصرة",
                 sw: CLLocationCoordinate2D(latitude: 30.35, longitude: 47.70),
                 ne: CLLocationCoordinate2D(latitude: 30.66, longitude: 48.06)),
    ]
}

// MARK: - Formatting helpers

enum Format {
    static func distance(_ metres: Double, locale: String = L10n.lang) -> String {
        if metres < 1000 {
            return "\(Int(metres.rounded())) \("م".loc)"
        }
        let km = metres / 1000
        return String(format: "%.1f %@", km, "كم".loc)
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h) \("ساعة".loc) \(m) \("دقيقة".loc)" }
        if m > 0 { return "\(m) \("دقيقة".loc)" }
        return "\(max(total, 1)) \("ثانية".loc)"
    }
}
