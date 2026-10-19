import SwiftUI
import MapLibre

// MARK: - Map styles (OpenFreeMap — free, no API key)

enum MapStyleKind {
    /// Day style.
    static let dayURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    /// Night style — paired over the same OpenMapTiles data, so switching
    /// is just a style swap, exactly like the plan's day/night pair idea.
    static let nightURL = URL(string: "https://tiles.openfreemap.org/styles/dark")!

    static func url(for scheme: ColorScheme) -> URL {
        scheme == .dark ? nightURL : dayURL
    }
}

// MARK: - MapLibre bridge
//
// Deliberately small for the skeleton: full-screen map, user location dot,
// one selected-place pin, pins for user-added local places, and the route
// polyline. Camera moves are driven by `cameraTarget` + `cameraNonce`
// (bump the nonce to re-centre on the same coordinate again).

struct MapBridge: UIViewRepresentable {
    var selectedPlace: Place?
    var localPlaces: [LocalPlace] = []
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var cameraTarget: CLLocationCoordinate2D?
    var cameraNonce: Int = 0
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?

    @Environment(\.colorScheme) private var scheme

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: MapStyleKind.url(for: scheme))
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.attributionButton.isHidden = false // OSM attribution must stay visible/reachable
        map.logoView.isHidden = true
        // Baghdad is only the starting point — Atlas is a global app.
        map.setCenter(CLLocationCoordinate2D(latitude: 33.3152, longitude: 44.3661),
                      zoomLevel: 11, animated: false)
        let press = UILongPressGestureRecognizer(target: context.coordinator,
                                                 action: #selector(Coordinator.handleLongPress(_:)))
        map.addGestureRecognizer(press)
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.parent = self

        // Day/night: swap the style only when the scheme actually changed.
        let wanted = MapStyleKind.url(for: scheme)
        if map.styleURL != wanted {
            map.styleURL = wanted
            context.coordinator.styleReloadPending = true // annotations re-added on style load
            return
        }
        context.coordinator.refreshAnnotations()
        context.coordinator.applyCameraIfNeeded()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapBridge
        weak var map: MLNMapView?
        var styleReloadPending = false
        private var lastCameraNonce = 0
        private var pinAnnotations: [MLNPointAnnotation] = []
        private var routeAnnotation: MLNPolyline?

        init(_ parent: MapBridge) { self.parent = parent }

        // MARK: Annotations

        func refreshAnnotations() {
            guard let map else { return }
            if !pinAnnotations.isEmpty { map.removeAnnotations(pinAnnotations) }
            pinAnnotations.removeAll()
            if let old = routeAnnotation { map.removeAnnotation(old); routeAnnotation = nil }

            if let place = parent.selectedPlace {
                let pin = MLNPointAnnotation()
                pin.coordinate = place.coordinate
                pin.title = place.name
                pin.subtitle = place.address
                pinAnnotations.append(pin)
            }
            for local in parent.localPlaces {
                let pin = MLNPointAnnotation()
                pin.coordinate = local.coordinate
                pin.title = local.name
                pin.subtitle = local.category
                pinAnnotations.append(pin)
            }
            if !pinAnnotations.isEmpty { map.addAnnotations(pinAnnotations) }

            if parent.routeCoordinates.count > 1 {
                let line = MLNPolyline(coordinates: parent.routeCoordinates,
                                       count: UInt(parent.routeCoordinates.count))
                routeAnnotation = line
                map.addAnnotation(line)
            }
        }

        func applyCameraIfNeeded() {
            guard let map, parent.cameraNonce != lastCameraNonce,
                  let target = parent.cameraTarget else { return }
            lastCameraNonce = parent.cameraNonce
            map.setCenter(target, zoomLevel: max(map.zoomLevel, 15), animated: true)
        }

        // MARK: Delegate

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // A style swap wipes annotations — put them back.
            refreshAnnotations()
            applyCameraIfNeeded()
        }

        func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool { true }

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            if annotation is MLNPolyline { return .systemBlue }
            return .black
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat { 5 }

        // MARK: Long press → add-a-place flow starts here

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let map else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            parent.onLongPress?(coordinate)
        }
    }
}
