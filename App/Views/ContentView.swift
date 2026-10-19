import SwiftUI
import CoreLocation

// MARK: - Main screen
//
// Full-screen map + floating Liquid Glass search bar on top + bottom
// sheets for the place card and directions. The suggestions panel sits
// directly under the search bar (between the bar and the keyboard),
// and every suggestion shows its distance — the developer's standing
// search spec, carried into Atlas from day one.

struct ContentView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var saved: SavedPlacesStore
    @EnvironmentObject private var local: LocalPlacesStore

    @StateObject private var search = SearchService()
    @StateObject private var routing = RouteService()
    @StateObject private var offline = OfflineService()

    @State private var query = ""
    @State private var selectedPlace: Place?
    @State private var routeDestination: Place?
    @State private var cameraTarget: CLLocationCoordinate2D?
    @State private var cameraNonce = 0
    @State private var longPressCoordinate: CLLocationCoordinate2D?
    @State private var showOffline = false
    @State private var showSettings = false
    @State private var showSaved = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            MapBridge(selectedPlace: selectedPlace,
                      localPlaces: local.places,
                      routeCoordinates: routing.route?.coordinates ?? [],
                      cameraTarget: cameraTarget,
                      cameraNonce: cameraNonce,
                      onLongPress: { longPressCoordinate = $0 })
                .ignoresSafeArea()

            VStack(spacing: 10) {
                searchBar
                if searchFocused || !query.isEmpty {
                    suggestionsPanel
                }
                Spacer()
                sideButtons
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .onAppear { location.requestAndStart() }
        .onChange(of: query) { _, newValue in
            search.search(query: newValue, near: location.location)
        }
        // Place card — bottom sheet
        .sheet(item: $selectedPlace) { place in
            PlaceCardView(place: place,
                          onDirections: {
                              selectedPlace = nil
                              routeDestination = place
                          })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Directions — bottom sheet
        .sheet(item: $routeDestination) { destination in
            DirectionsView(destination: destination, routing: routing)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Add a local place (long-press on the map)
        .sheet(item: coordinateItem) { item in
            AddLocalPlaceView(latitude: item.coordinate.latitude,
                              longitude: item.coordinate.longitude)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showOffline) {
            OfflineView(offline: offline)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSaved) {
            SavedPlacesView(onPick: { place in
                showSaved = false
                focus(place)
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // Widget deep links: atlas://home , atlas://work
        .onOpenURL { url in
            guard url.scheme == "atlas" else { return }
            if url.host == "home", let home = saved.home { routeDestination = home }
            if url.host == "work", let work = saved.work { routeDestination = work }
        }
    }

    // Bridges the optional long-press coordinate into sheet(item:).
    private var coordinateItem: Binding<CoordinateItem?> {
        Binding(get: { longPressCoordinate.map(CoordinateItem.init) },
                set: { longPressCoordinate = $0?.coordinate })
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("ابحث عن مكان أو عنوان".loc, text: $query)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                    search.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassPill()
    }

    // MARK: Suggestions (bar ↔ keyboard), distance always shown

    private var suggestionsPanel: some View {
        VStack(spacing: 0) {
            if search.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("جارٍ البحث…".loc).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            } else if search.results.isEmpty && query.count >= 3 {
                Text("لا توجد نتائج".loc)
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(search.results) { place in
                            Button { focus(place) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name).font(.subheadline.weight(.bold))
                                            .foregroundStyle(adaptiveInk)
                                            .lineLimit(1)
                                        if !place.address.isEmpty {
                                            Text(place.address).font(.caption)
                                                .foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    if let metres = place.distance(from: location.location) {
                                        Text(Format.distance(metres))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .glass(cornerRadius: 22)
    }

    // MARK: Side buttons

    private var sideButtons: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                sideButton("house.fill") { if let home = saved.home { routeDestination = home } }
                sideButton("briefcase.fill") { if let work = saved.work { routeDestination = work } }
                sideButton("bookmark.fill") { showSaved = true }
                sideButton("arrow.down.circle.fill") { showOffline = true }
                sideButton("plus.circle.fill") {
                    if let coordinate = location.location?.coordinate {
                        longPressCoordinate = coordinate
                    }
                }
                sideButton("gearshape.fill") { showSettings = true }
                // Single press ONLY: centre on my location (standing spec).
                sideButton("location.fill") {
                    if let coordinate = location.location?.coordinate {
                        cameraTarget = coordinate
                        cameraNonce += 1
                    }
                }
            }
        }
    }

    private func sideButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(GlassCircleButtonStyle())
    }

    // MARK: Selection

    private func focus(_ place: Place) {
        searchFocused = false
        query = ""
        search.clear()
        cameraTarget = place.coordinate
        cameraNonce += 1
        selectedPlace = place
        // Enrich the card from Nominatim details (user-triggered = allowed).
        if let ref = place.osmRef {
            Task {
                if let detailed = try? await search.fetchDetails(osmRef: ref) {
                    var merged = place
                    merged.phone = detailed.phone
                    merged.website = detailed.website
                    merged.openingHours = detailed.openingHours
                    if selectedPlace?.id == place.id { selectedPlace = merged }
                }
            }
        }
    }
}

private struct CoordinateItem: Identifiable {
    var coordinate: CLLocationCoordinate2D
    var id: String { "\(coordinate.latitude),\(coordinate.longitude)" }
}
