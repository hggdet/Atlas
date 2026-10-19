import SwiftUI

// MARK: - Directions (bottom-sheet content)
//
// Fetches a Valhalla route from the user's location to the destination
// and lists its steps. This is a route PREVIEW, not turn-by-turn
// navigation — Ferrostar integration (rerouting, voice, snapping) is a
// later phase and the sheet says nothing stronger than that.

struct DirectionsView: View {
    var destination: Place
    @ObservedObject var routing: RouteService

    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss
    @State private var mode: TravelMode = .driving

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("الاتجاهات".loc).font(.headline.weight(.black))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
            }
            Text(destination.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)

            Picker("", selection: $mode) {
                ForEach(TravelMode.allCases) { m in
                    Label(m.label, systemImage: m.icon).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in fetch() }

            if routing.isRouting {
                HStack(spacing: 8) { ProgressView(); Text("…").font(.footnote) }
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
            } else if let error = routing.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            } else if let route = routing.route {
                HStack(spacing: 16) {
                    Label(Format.duration(route.duration), systemImage: "clock.fill")
                    Label(Format.distance(route.distance), systemImage: "road.lanes")
                }
                .font(.subheadline.weight(.bold))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(route.steps) { step in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "arrow.turn.up.right")
                                    .font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.instruction).font(.subheadline)
                                    Text(Format.distance(step.distance))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else if location.location == nil {
                Text("فعّل خدمات الموقع حتى نحسب المسار من موقعك.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .onAppear { fetch() }
        .onDisappear { routing.clear() }
    }

    private func fetch() {
        guard let origin = location.location?.coordinate else { return }
        Task { await routing.fetchRoute(from: origin, to: destination.coordinate, mode: mode) }
    }
}
