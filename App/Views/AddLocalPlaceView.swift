import SwiftUI

// MARK: - Add a local place — the core Atlas contribution flow
//
// Opened by long-pressing the map (or the + button, which uses the
// user's current location). Saves to LocalPlacesStore (JSON on device);
// shared upload arrives with the Supabase sync layer, and the form
// copy says exactly that.

struct AddLocalPlaceView: View {
    var latitude: Double
    var longitude: Double

    @EnvironmentObject private var local: LocalPlacesStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "محل"
    @State private var note = ""

    private let categories = ["محل", "مطعم", "مخبز", "صيدلية", "معلم", "موقف", "أخرى"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("أضف مكاناً".loc).font(.title3.weight(.black))

            TextField("اسم المكان".loc, text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("النوع".loc).font(.subheadline.weight(.semibold))
                Spacer()
                Picker("النوع".loc, selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }

            TextField("معلومة إضافية (اختياري)".loc, text: $note)
                .textFieldStyle(.roundedBorder)

            Text("ينحفظ بجهازك هسه، وينشر للكل من يشتغل خادم المشاركة.".loc)
                .font(.caption).foregroundStyle(.secondary)

            Button {
                local.add(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                          category: category, note: note,
                          latitude: latitude, longitude: longitude)
                dismiss()
            } label: {
                Text("أضف مكاناً".loc)
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
