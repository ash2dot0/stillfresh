import Foundation

private func toISO8601WithFractional(_ s: String) -> String {
    if s.count == 10, s.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil {
        return "\(s)T12:00:00.000Z"
    }
    let f = ISO8601DateFormatter()
    if let d = f.date(from: s) { return ISO8601Helper.formatter.string(from: d) }
    return s
}

private func storageMode(from s: String) -> StorageMode {
    switch s.lowercased() {
    case "pantry": return .pantry
    case "refrigerator": return .fridge
    case "freezer": return .freezer
    default: return .fridge
    }
}

extension WorkerSimpleItem {
    func toReceiptItem() -> ReceiptItem {
        let defaultMode = storageMode(from: recommended_storage)
        let expiryMap: [StorageMode: String] = [
            .pantry: toISO8601WithFractional(expiry.pantry),
            .fridge: toISO8601WithFractional(expiry.refrigerator),
            .freezer: toISO8601WithFractional(expiry.freezer)
        ]
        let purchaseISO = toISO8601WithFractional(purchase_date)
        let purchaseDate = ISO8601Helper.formatter.date(from: purchaseISO) ?? Date()
        return ReceiptItem(
            name: name,
            quantity: max(1, quantity.count),
            purchasedAt: purchaseDate,
            defaultStorage: defaultMode,
            expiryByStorageISO8601: expiryMap,
            selectedStorage: defaultMode,
            userOverrideExpiryISO8601: nil,
            perUnitAmount: quantity.amount_per_unit,
            perUnitUnit: quantity.unit,
            pricePerUnit: price_per_unit,
            totalPrice: total_price
        )
    }
}

