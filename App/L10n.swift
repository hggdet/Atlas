import Foundation

/// App language: "ar" (default), "en", "ku" (Kurdish Sorani).
/// Same pattern as the developer's other apps: UI strings are written in
/// Arabic in the code; `String.loc` swaps in the English/Kurdish text from
/// the table when the user picks another language. Strings missing from
/// the table simply stay Arabic, so new UI never breaks in other languages.
enum L10n {
    static var lang: String {
        UserDefaults.standard.string(forKey: "atlas.language") ?? "ar"
    }

    static let table: [String: (en: String, ku: String)] = [
        "ابحث عن مكان أو عنوان": ("Search for a place or address", "بگەڕێ بۆ شوێنێک یان ناونیشانێک"),
        "الاتجاهات": ("Directions", "ڕێنیشاندان"),
        "حفظ": ("Save", "پارێزە"),
        "محفوظ": ("Saved", "پارێزراوە"),
        "مشاركة": ("Share", "ھاوبەشکردن"),
        "البيت": ("Home", "ماڵ"),
        "الشغل": ("Work", "کار"),
        "أماكني": ("My Places", "شوێنەکانم"),
        "أضف مكاناً": ("Add a Place", "شوێنێک زیاد بکە"),
        "خرائط بدون إنترنت": ("Offline Maps", "نەخشە بەبێ ئینتەرنێت"),
        "الإعدادات": ("Settings", "ڕێکخستنەکان"),
        "اللغة": ("Language", "زمان"),
        "العربية": ("Arabic", "عەرەبی"),
        "المظهر": ("Appearance", "ڕووخسار"),
        "تلقائي (نهار/ليل)": ("Automatic (day/night)", "خۆکار (ڕۆژ/شەو)"),
        "حول اطلس": ("About Atlas", "دەربارەی اطلس"),
        "من تطوير": ("Developed by", "لە گەشەپێدانی"),
        "عبدالباسط خضير": ("Abdulbasit Khudair", "عبدالباسط خضير"),
        "الإصدار": ("Version", "وەشان"),
        "مصدر البيانات": ("Data Source", "سەرچاوەی داتا"),
        "سيارة": ("Car", "ئۆتۆمبێل"),
        "مشي": ("Walking", "پیاسە"),
        "دراجة": ("Cycling", "پاسکیل"),
        "ابدأ": ("Start", "دەستپێبکە"),
        "إغلاق": ("Close", "داخستن"),
        "حذف": ("Delete", "سڕینەوە"),
        "تنزيل": ("Download", "داگرتن"),
        "جارٍ التنزيل…": ("Downloading…", "دادەگیرێت…"),
        "لا توجد نتائج": ("No results", "ھیچ ئەنجامێک نییە"),
        "جارٍ البحث…": ("Searching…", "دەگەڕێت…"),
        "اسم المكان": ("Place name", "ناوی شوێن"),
        "النوع": ("Type", "جۆر"),
        "معلومة إضافية (اختياري)": ("Extra info (optional)", "زانیاری زیاتر (ئارەزوومەندانە)"),
        "ينحفظ بجهازك هسه، وينشر للكل من يشتغل خادم المشاركة.": ("Saved on your device now; shared with everyone once the sharing server is live.", "ئێستا لە ئامێرەکەت دەپارێزرێت؛ کاتێک سێرڤەری ھاوبەشکردن کارا بوو لەگەڵ ھەمووان ھاوبەش دەکرێت."),
        "المناطق المحمّلة": ("Downloaded areas", "ناوچە داگیراوەکان"),
        "لا توجد مناطق محمّلة بعد": ("No downloaded areas yet", "ھێشتا ھیچ ناوچەیەک دانەگیراوە"),
        "م": ("m", "م"),
        "كم": ("km", "کم"),
        "ساعة": ("h", "کاتژمێر"),
        "دقيقة": ("min", "خولەک"),
        "ثانية": ("sec", "چرکە"),
        "موقعي": ("My location", "شوێنەکەم"),
        "حدود معروفة": ("Known limitations", "سنوورە ناسراوەکان"),
        "أماكن يضيفها الناس": ("Places added by people", "شوێنەکان کە خەڵک زیادی دەکەن"),
    ]
}

extension String {
    var loc: String {
        guard let entry = L10n.table[self] else { return self }
        switch L10n.lang {
        case "en": return entry.en
        case "ku": return entry.ku
        default: return self
        }
    }
}
