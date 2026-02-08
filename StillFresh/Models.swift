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
         totalPrice: Double? = nil) {
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
    }

    var effectiveExpiryISO8601: String {
        userOverrideExpiryISO8601 ?? (expiryByStorageISO8601[selectedStorage] ?? expiryByStorageISO8601[defaultStorage] ?? "")
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

    // Determine urgency bucket relative to now
    enum Urgency: String { case expired, soon, fresh }

    func urgency(relativeTo now: Date = Date()) -> Urgency {
        guard let d = ISO8601Helper.formatter.date(from: effectiveExpiryISO8601) else { return .fresh }
        let delta = d.timeIntervalSince(now)
        if delta < 0 { return .expired }
        if delta <= 48 * 3600 { return .soon } // within 48h
        return .fresh
    }

    var quantityLabel: String { "×\(quantity)" }

    var displayName: String {
        if let amt = perUnitAmount, let unit = perUnitUnit, amt > 0 {
            // Format amount without trailing .0 if possible
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
	        // Swift string literals treat "\s" as an escape; use a raw string so the regex sees \s.
	        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
}
}

