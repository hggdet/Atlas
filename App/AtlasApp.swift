import SwiftUI
import MapLibre

@main
struct AtlasApp: App {
    init() {
        // Ambient tile cache (256 MB): streets the user already viewed
        // reload instantly instead of downloading again.
        MLNOfflineStorage.shared.setMaximumAmbientCacheSize(256 * 1024 * 1024) { _ in }
    }

    @AppStorage("atlas.language") private var language = "ar"
    /// "system" (default) | "light" | "dark" — system gives the automatic
    /// day/night style pairing; light/dark pin it from Settings.
    @AppStorage("atlas.appearance") private var appearance = "system"
    @StateObject private var location = LocationService()
    @StateObject private var savedPlaces = SavedPlacesStore()
    @StateObject private var localPlaces = LocalPlacesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(language)
                .environmentObject(location)
                .environmentObject(savedPlaces)
                .environmentObject(localPlaces)
                .environment(\.layoutDirection, language == "en" ? .leftToRight : .rightToLeft)
                .environment(\.locale, Locale(identifier: language == "ku" ? "ckb" : language))
                .preferredColorScheme(appearance == "light" ? .light : (appearance == "dark" ? .dark : nil))
        }
    }
}
