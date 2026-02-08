import Foundation

// Simplified AI response schema as requested
struct WorkerReceiptResponse: Codable {
    let items: [WorkerSimpleItem]
}

struct WorkerSimpleItem: Codable {
    let name: String
    let quantity: WorkerQuantity
    let purchase_date: String            // ISO-8601 date or YYYY-MM-DD
    let expiry: WorkerSimpleExpiry       // per storage
    let recommended_storage: String      // "pantry" | "fridge" | "freezer"
    let price_per_unit: Double?
    let total_price: Double?

    enum CodingKeys: String, CodingKey {
        case name, quantity, purchase_date, expiry, recommended_storage, price_per_unit, total_price
    }

    init(name: String,
         quantity: WorkerQuantity,
         purchase_date: String,
         expiry: WorkerSimpleExpiry,
         recommended_storage: String,
         price_per_unit: Double? = nil,
         total_price: Double? = nil) {
        self.name = name
        self.quantity = quantity
        self.purchase_date = purchase_date
        self.expiry = expiry
        self.recommended_storage = recommended_storage
        self.price_per_unit = price_per_unit
        self.total_price = total_price
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.quantity = try c.decode(WorkerQuantity.self, forKey: .quantity)
        self.purchase_date = try c.decode(String.self, forKey: .purchase_date)
        self.expiry = try c.decode(WorkerSimpleExpiry.self, forKey: .expiry)
        self.recommended_storage = try c.decode(String.self, forKey: .recommended_storage)
        // Decode price fields allowing string or number
        if let d = try? c.decode(Double.self, forKey: .price_per_unit) { self.price_per_unit = d }
        else if let s = try? c.decode(String.self, forKey: .price_per_unit), let d = Double(s) { self.price_per_unit = d }
        else { self.price_per_unit = nil }

        if let d = try? c.decode(Double.self, forKey: .total_price) { self.total_price = d }
        else if let s = try? c.decode(String.self, forKey: .total_price), let d = Double(s) { self.total_price = d }
        else { self.total_price = nil }
    }
}

struct WorkerQuantity: Codable {
    let count: Int
    let amount_per_unit: Double?
    let unit: String?

    enum CodingKeys: String, CodingKey { case count, amount_per_unit, unit }

    init(count: Int, amount_per_unit: Double? = nil, unit: String? = nil) {
        self.count = max(1, count)
        self.amount_per_unit = amount_per_unit
        self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // count can be Int or String; normalize
        if let v = try? c.decode(Int.self, forKey: .count) { self.count = max(1, v) }
        else if let s = try? c.decode(String.self, forKey: .count), let v = Int(s) { self.count = max(1, v) }
        else { self.count = 1 }
        // amount_per_unit can be Double or String
        if let d = try? c.decode(Double.self, forKey: .amount_per_unit) { self.amount_per_unit = d }
        else if let s = try? c.decode(String.self, forKey: .amount_per_unit), let d = Double(s) { self.amount_per_unit = d }
        else { self.amount_per_unit = nil }
        self.unit = try? c.decode(String.self, forKey: .unit)
    }
}

struct WorkerSimpleExpiry: Codable {
    let pantry: String   // ISO-8601 or YYYY-MM-DD
    let refrigerator: String
    let freezer: String
}

