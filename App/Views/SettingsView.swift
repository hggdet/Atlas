import SwiftUI

// MARK: - Settings + About
//
// About carries the OSM attribution and the honest limitations list —
// both are part of the skeleton's contract, not decoration.

struct SettingsView: View {
    @AppStorage("atlas.language") private var language = "ar"
    @AppStorage("atlas.appearance") private var appearance = "system"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("الإعدادات".loc).font(.title3.weight(.black))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("اللغة".loc).font(.subheadline.weight(.bold))
                Picker("اللغة".loc, selection: $language) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                    Text("کوردی").tag("ku")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("المظهر".loc).font(.subheadline.weight(.bold))
                Picker("المظهر".loc, selection: $appearance) {
                    Text("تلقائي (نهار/ليل)".loc).tag("system")
                    Text("نهاري").tag("light")
                    Text("ليلي").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("حول اطلس".loc).font(.subheadline.weight(.bold))
                Text("\("الإصدار".loc): 0.1.0 (هيكل أولي)")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("\("من تطوير".loc) \("عبدالباسط خضير".loc)")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("\("مصدر البيانات".loc): © OpenStreetMap contributors — MapLibre · OpenFreeMap · Photon · Valhalla")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("حدود معروفة".loc).font(.subheadline.weight(.bold))
                ForEach([
                    "البحث والاتجاهات بدون إنترنت غير جاهزين بعد — التنزيل الحالي للبلاطات فقط.",
                    "الأماكن التي تضيفها تُحفظ بجهازك فقط حالياً — المشاركة للكل تأتي مع خادم Supabase.",
                    "الملاحة خطوة بخطوة بالصوت (Ferrostar) مرحلة لاحقة — الاتجاهات الحالية قائمة خطوات.",
                    "خدمات البحث والتوجيه العامة للتجربة — الإطلاق يحتاج استضافة ذاتية.",
                ], id: \.self) { line in
                    Text("• \(line)").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
