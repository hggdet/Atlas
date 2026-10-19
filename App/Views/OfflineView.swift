import SwiftUI

// MARK: - Offline provinces
//
// Tiles only — the header copy states the skeleton's real scope so no
// one mistakes a tile download for offline search/routing.

struct OfflineView: View {
    @ObservedObject var offline: OfflineService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("خرائط بدون إنترنت".loc).font(.title3.weight(.black))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
            }

            Text("التنزيل يحفظ بلاطات الخريطة فقط. البحث والاتجاهات بدون إنترنت مرحلة لاحقة.")
                .font(.caption).foregroundStyle(.secondary)

            if offline.downloading {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: offline.fraction)
                    Text("\("جارٍ التنزيل…".loc) \(Int(offline.fraction * 100))٪")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = offline.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            ForEach(Province.catalogue) { province in
                HStack {
                    Text(province.name).font(.subheadline.weight(.bold))
                    Spacer()
                    if offline.isDownloaded(province) {
                        Text("مكتمل").font(.caption.weight(.semibold)).foregroundStyle(.green)
                    } else {
                        Button("تنزيل".loc) {
                            offline.download(province: province, styleURL: MapStyleKind.dayURL)
                        }
                        .font(.subheadline.weight(.bold))
                        .disabled(offline.downloading)
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }

            Text("المناطق المحمّلة".loc).font(.headline.weight(.black)).padding(.top, 6)
            if offline.infos.isEmpty {
                Text("لا توجد مناطق محمّلة بعد".loc).font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(offline.infos) { info in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name).font(.subheadline.weight(.semibold))
                            Text("\(info.stateText) \(info.sizeText)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) { offline.delete(info) } label: {
                            Image(systemName: "trash")
                        }
                    }
                    Divider()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .onAppear { offline.refreshSnapshot() }
    }
}
