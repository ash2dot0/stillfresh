import Foundation

// Shared ISO-8601 formatter with fractional seconds to ensure consistent parsing/formatting
enum ISO8601Helper {
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

enum StorageMode: String, CaseIterable, Identifiable, Codable {
    case pantry
    case fridge
    case freezer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pantry: return "Pantry"
        case .fridge: return "Refrigerator"
        case .freezer: return "Freezer"
        }
    }

    var iconName: String {
        switch self {
        case .pantry: return "cabinet"
        case .fridge: return "snowflake"
        case .freezer: return "thermometer.snowflake"
        }
    }
}

struct ReceiptItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var quantity: Int
    var purchasedAt: Date = Date()
    var defaultStorage: StorageMode

    /// Expiry estimates returned by AI for each storage mode.
    var expiryByStorageISO8601: [StorageMode: String] // ISO-8601 date-time string

    /// The user-selected storage mode (defaults to AI's defaultStorage).
    var selectedStorage: StorageMode

    /// Optional user override. If set, this is the "truth" shown in UI.
    var userOverrideExpiryISO8601: String?

    var perUnitAmount: Double?
    var perUnitUnit: String?
    var pricePerUnit: Double?
    var totalPrice: Double?

    /// User marks item as used (saved) rather than wasted.
    /// Kept on the item so history + weekly trends stay correct.
    var isUsed: Bool = false
    var usedAt: Date? = nil

    /// Stable per-unit price derived once from `totalPrice` when
    /// `pricePerUnit` is missing. This lets quantity edits update totals.
    var unitPriceFallback: Double? = nil

    init(id: UUID = UUID(),
         name: String,
         quantity: Int = 1,
         purchasedAt: Date = Date(),
         defaultStorage: StorageMode,
         expiryByStorageISO8601: [StorageMode: String],
         selectedStorage: StorageMode? = nil,
         userOverrideExpiryISO8601: String? = nil,
         perUnitAmount: Double? = nil,
         perUnitUnit: String? = nil,
         pricePerUnit: Double? = nil,
         totalPrice: Double? = nil,
         isUsed: Bool = false,
         usedAt: Date? = nil,
         unitPriceFallback: Double? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.purchasedAt = purchasedAt
        self.defaultStorage = defaultStorage
        self.expiryByStorageISO8601 = expiryByStorageISO8601
        self.selectedStorage = selectedStorage ?? defaultStorage
        self.userOverrideExpiryISO8601 = userOverrideExpiryISO8601
        self.perUnitAmount = perUnitAmount
        self.perUnitUnit = perUnitUnit
        self.pricePerUnit = pricePerUnit
        self.totalPrice = totalPrice

        self.isUsed = isUsed
        self.usedAt = usedAt

        if let provided = unitPriceFallback {
            self.unitPriceFallback = provided
        } else if self.pricePerUnit == nil, let total = totalPrice {
            self.unitPriceFallback = total / Double(max(1, quantity))
        } else {
            self.unitPriceFallback = nil
        }
    }

    var effectiveExpiryISO8601: String {
        userOverrideExpiryISO8601
        ?? (expiryByStorageISO8601[selectedStorage]
            ?? expiryByStorageISO8601[defaultStorage]
            ?? "")
    }

    /// Best-effort total cost that responds to quantity edits.
    var effectiveTotalCost: Double {
        let q = Double(max(1, quantity))
        if let ppu = pricePerUnit { return ppu * q }
        if let unit = unitPriceFallback { return unit * q }
        if let total = totalPrice { return total }
        return 0
    }
}

struct ReceiptSession: Identifiable {
    let id: UUID
    var createdAt: Date
    var scanCount: Int
    var items: [ReceiptItem]
}

enum ProcessingStage: String, CaseIterable, Identifiable {
    case capturing = "Capturing"
    case enhancing = "Enhancing"
    case understanding = "Understanding"
    case organizing = "Organizing"

    var id: String { rawValue }
}

struct AIReceiptResponse: Codable {
    struct Item: Codable {
        let name: String
        let quantity: Int?
        let default_storage: String
        let expiry: Expiry

        struct Expiry: Codable {
            let pantry: String
            let fridge: String
            let freezer: String
        }
    }

    let receipt_id: String?
    let items: [Item]
}

// MARK: - ReceiptItem UI + business helpers
extension ReceiptItem {

    // Simple emoji based on common food keywords
    var iconEmoji: String {
        let n = name.lowercased()
        if n.contains("banana") { return "🍌" }
        if n.contains("strawberry") || n.contains("berries") { return "🍓" }
        if n.contains("apple") { return "🍎" }
        if n.contains("chicken") { return "🍗" }
        if n.contains("beef") || n.contains("steak") { return "🥩" }
        if n.contains("milk") { return "🥛" }
        if n.contains("bread") { return "🍞" }
        if n.contains("egg") { return "🥚" }
        if n.contains("fish") || n.contains("salmon") { return "🐟" }
        if n.contains("cheese") { return "🧀" }
        if n.contains("lettuce") || n.contains("salad") { return "🥬" }
        if n.contains("tomato") { return "🍅" }
        if n.contains("yogurt") { return "🥣" }
        return "🛒"
    }

    enum Urgency: String { case expired, soon, fresh }

    /// Robust ISO8601 parsing (with/without fractional seconds).
    private func parseISO8601(_ s: String) -> Date? {
        if let d = ISO8601Helper.formatter.date(from: s) { return d }

        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime]
        if let d = f1.date(from: s) { return d }

        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f2.date(from: s)
    }

    /// Interprets `effectiveExpiryISO8601` as a calendar date and returns the start of that day
    /// in the device's local timezone (prevents UTC shifting the date).
    func effectiveExpiryDayStartLocal() -> Date? {
        guard let abs = parseISO8601(effectiveExpiryISO8601) else { return nil }
        return ReceiptItem.localDayStartPreservingUTCDate(abs)
    }

    /// Converts an absolute Date into "the same YYYY-MM-DD" in local time.
    /// We take the UTC year/month/day from the Date, then construct a local-date at noon (DST-safe),
    /// then return start-of-day for that local date.
    private static func localDayStartPreservingUTCDate(_ absolute: Date) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!

        let ymd = utc.dateComponents([.year, .month, .day], from: absolute)

        var local = Calendar.current
        local.timeZone = .current

        var noon = DateComponents()
        noon.year = ymd.year
        noon.month = ymd.month
        noon.day = ymd.day
        noon.hour = 12 // noon avoids DST edge cases

        guard let localNoon = local.date(from: noon) else { return nil }
        return local.startOfDay(for: localNoon)
    }

    /// Determine urgency bucket relative to now (calendar-day safe).
    /// ✅ "Today" is NOT expired.
    func urgency(relativeTo now: Date = Date()) -> Urgency {
        guard let expiryDayStart = effectiveExpiryDayStartLocal() else { return .fresh }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)

        if expiryDayStart < todayStart { return .expired }

        // treat expiry as end-of-day for "soon"
        let endExclusive = cal.date(byAdding: .day, value: 1, to: expiryDayStart)
            ?? expiryDayStart.addingTimeInterval(24 * 3600)

        let remaining = endExclusive.timeIntervalSince(now)
        if remaining <= 48 * 3600 { return .soon }

        return .fresh
    }

    var quantityLabel: String { "×\(quantity)" }

    var displayName: String {
        if let amt = perUnitAmount, let unit = perUnitUnit, amt > 0 {
            let amtString: String = amt == floor(amt) ? String(Int(amt)) : String(amt)
            return "\(name) (\(amtString) \(unit))"
        }
        return name
    }

    /// Normalized key used to group the same item across multiple purchases.
    var canonicalKey: String {
        name
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

