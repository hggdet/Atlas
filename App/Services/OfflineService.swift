import Foundation
import CoreLocation
import MapLibre

// MARK: - Offline tile packs (MapLibre Offline Storage)
//
// SCOPE — read this before promising offline anything:
// this service downloads MAP TILES ONLY. A downloaded province renders
// with no connection, but SEARCH and ROUTING still need the network in
// this skeleton: on-device search + routing (local index, valhalla-mobile)
// are a later technical phase, marked in the UI as a known limitation.
//
// Implementation follows MapLibre's documented usage strictly:
//  - reloadPacks() runs ONCE at startup (it invalidates pack objects).
//  - The UI renders value snapshots (OfflinePackInfo), never live packs.
//  - Progress notifications refresh the snapshot, throttled.

struct OfflinePackInfo: Identifiable {
    var id: ObjectIdentifier
    var name: String
    var stateText: String
    var sizeText: String
}

final class OfflineService: ObservableObject {
    @Published var infos: [OfflinePackInfo] = []
    @Published var downloading = false
    @Published var fraction: Double = 0
    @Published var lastError: String?

    private var packsByID: [ObjectIdentifier: MLNOfflinePack] = [:]
    private var lastSnapshotAt = Date.distantPast

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressChanged(_:)),
                                               name: Notification.Name.MLNOfflinePackProgressChanged,
                                               object: nil)
        MLNOfflineStorage.shared.reloadPacks()
        refreshSnapshot()
    }

    @objc private func progressChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastSnapshotAt) < 0.5 { return }
            self.refreshSnapshot()
        }
    }

    func refreshSnapshot() {
        lastSnapshotAt = Date()
        let packs = MLNOfflineStorage.shared.packs ?? []
        packsByID = Dictionary(uniqueKeysWithValues: packs.map { (ObjectIdentifier($0), $0) })
        var anyActive = false
        var best = 0.0
        infos = packs.map { pack in
            let p = pack.progress
            if pack.state == .active {
                anyActive = true
                if p.countOfResourcesExpected > 0 {
                    best = max(best, Double(p.countOfResourcesCompleted) / Double(p.countOfResourcesExpected))
                }
            }
            return OfflinePackInfo(id: ObjectIdentifier(pack),
                                   name: String(data: pack.context, encoding: .utf8) ?? "منطقة محمّلة",
                                   stateText: Self.stateText(of: pack),
                                   sizeText: Self.sizeText(of: pack))
        }
        downloading = anyActive
        fraction = anyActive ? best : 0
    }

    /// Download one province from the catalogue. Capped at zoom 14 —
    /// a whole province at zoom 15 would be several GB.
    func download(province: Province, styleURL: URL) {
        guard !downloading else { return }
        lastError = nil
        let bounds = MLNCoordinateBounds(sw: province.sw, ne: province.ne)
        let region = MLNTilePyramidOfflineRegion(styleURL: styleURL, bounds: bounds,
                                                 fromZoomLevel: 10, toZoomLevel: 14)
        let context = province.name.data(using: .utf8) ?? Data()
        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { [weak self] pack, error in
            DispatchQueue.main.async {
                if let error {
                    self?.lastError = error.localizedDescription
                    return
                }
                pack?.resume()
                self?.refreshSnapshot()
            }
        }
    }

    func delete(_ info: OfflinePackInfo) {
        guard let pack = packsByID[info.id] else { return }
        MLNOfflineStorage.shared.removePack(pack) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshSnapshot() }
        }
    }

    func isDownloaded(_ province: Province) -> Bool {
        infos.contains { $0.name == province.name }
    }

    private static func stateText(of pack: MLNOfflinePack) -> String {
        switch pack.state {
        case .active: return "جارٍ التنزيل…".loc
        case .complete: return "مكتمل"
        case .inactive: return "متوقف"
        case .invalid: return "غير صالح"
        case .unknown: return "—"
        @unknown default: return "—"
        }
    }

    private static func sizeText(of pack: MLNOfflinePack) -> String {
        let bytes = Double(pack.progress.countOfBytesCompleted)
        if bytes <= 0 { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
