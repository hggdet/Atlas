import Foundation
import CoreLocation

// MARK: - Routing via Valhalla
//
// Valhalla was chosen over OSRM in the studies: dynamic per-request costing,
// built-in narrative instructions, self-hostable on a small VPS from the
// 86 MB Iraq Geofabrik extract. The public endpoint below is the community
// demo — fine for the skeleton, NOT a production dependency; swap
// `RouteConfig.base` for the self-hosted instance at launch.
//
// Turn-by-turn navigation (off-route rerouting, voice prompts, location
// snapping) is Ferrostar's job and is a LATER phase — this service only
// fetches a route, its steps, and draws the line. It does not navigate.

enum RouteConfig {
    static var base = URL(string: "https://valhalla1.openstreetmap.de")!
}

@MainActor
final class RouteService: ObservableObject {
    @Published var route: RouteData?
    @Published var isRouting = false
    @Published var lastError: String?

    func fetchRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D,
                    mode: TravelMode) async {
        isRouting = true
        lastError = nil
        defer { isRouting = false }
        do {
            route = try await Self.requestRoute(from: from, to: to, mode: mode)
        } catch {
            lastError = error.localizedDescription
            route = nil
        }
    }

    func clear() { route = nil; lastError = nil }

    private static func requestRoute(from: CLLocationCoordinate2D,
                                     to: CLLocationCoordinate2D,
                                     mode: TravelMode) async throws -> RouteData {
        let body: [String: Any] = [
            "locations": [
                ["lat": from.latitude, "lon": from.longitude],
                ["lat": to.latitude, "lon": to.longitude],
            ],
            "costing": mode.costing,
            "language": "ar-AE", // Arabic narrative requested. NOTE (verified 2026-10-13): the public demo
            // endpoint answers in English anyway — Arabic instructions need the self-hosted instance.
            "directions_options": ["units": "kilometers"],
        ]
        var request = URLRequest(url: RouteConfig.base.appendingPathComponent("route"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(ValhallaResponse.self, from: data)
        guard let trip = decoded.trip, let leg = trip.legs.first else {
            throw NSError(domain: "AtlasRoute", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No route found"])
        }
        let coordinates = decodePolyline6(leg.shape)
        var steps: [RouteStep] = []
        for maneuver in leg.maneuvers {
            let idx = min(maneuver.begin_shape_index, max(coordinates.count - 1, 0))
            steps.append(RouteStep(instruction: maneuver.instruction,
                                   distance: maneuver.length * 1000,
                                   coordinate: coordinates.isEmpty ? from : coordinates[idx]))
        }
        return RouteData(distance: trip.summary.length * 1000,
                         duration: trip.summary.time,
                         coordinates: coordinates,
                         steps: steps)
    }

    /// Valhalla shapes are precision-6 encoded polylines.
    private static func decodePolyline6(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat = 0, lon = 0
        func nextValue() -> Int {
            var result = 0, shift = 0, byte = 0
            repeat {
                guard index < encoded.endIndex else { return result }
                byte = Int(encoded[index].unicodeScalars.first!.value) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }
        while index < encoded.endIndex {
            lat += nextValue()
            lon += nextValue()
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e6,
                                                      longitude: Double(lon) / 1e6))
        }
        return coordinates
    }
}

// MARK: - Wire model

private struct ValhallaResponse: Decodable {
    struct Trip: Decodable {
        struct Summary: Decodable { var length: Double; var time: Double } // length in km
        struct Maneuver: Decodable {
            var instruction: String
            var length: Double // km
            var begin_shape_index: Int
        }
        struct Leg: Decodable {
            var shape: String
            var maneuvers: [Maneuver]
        }
        var summary: Summary
        var legs: [Leg]
    }
    var trip: Trip?
}
