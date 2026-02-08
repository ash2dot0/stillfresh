import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var store: AppStore
    let item: ReceiptItem

    private var history: [ReceiptItem] {
        store.items
            .filter { $0.canonicalKey == item.canonicalKey }
            .sorted { $0.purchasedAt > $1.purchasedAt }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(item.iconEmoji).font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.headline)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("This purchase") {
                detailRow("Quantity", "\(item.quantity)")
                if let ppu = item.pricePerUnit {
                    detailRow("Price / unit", currency(ppu))
                }
                if let total = item.totalPrice {
                    detailRow("Total price", currency(total))
                }
                detailRow("Bought on", formatDate(item.purchasedAt))
                detailRow("Storage", storageLabel(item.selectedStorage))
                detailRow("Expires", formatDate(expiryDate(for: item)))
            }

            Section("AI expiry estimates") {
                HStack(alignment: .top, spacing: 12) {
                    expiryColumn(label: "Pantry", date: expiryFor(item, mode: .pantry))
                    Divider().frame(height: 28)
                    expiryColumn(label: "Refrigerator", date: expiryFor(item, mode: .fridge))
                    Divider().frame(height: 28)
                    expiryColumn(label: "Freezer", date: expiryFor(item, mode: .freezer))
                }
                .padding(.vertical, 2)
            }

            if history.count > 1 {
                Section("Purchase history") {
                    ForEach(history) { h in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(formatDate(h.purchasedAt))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("×\(h.quantity)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.secondary.opacity(0.15), in: Capsule())
                            }

                            Text("Expires: \(formatDate(expiryDate(for: h)))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Storage: \(storageLabel(h.selectedStorage))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 12) }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatDate(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: d)
    }

    private func formatDate(_ d: Date?) -> String {
        guard let d else { return "Unknown" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: d)
    }

    private func expiryDate(for item: ReceiptItem) -> Date? {
        ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601)
    }

    private func expiryFor(_ item: ReceiptItem, mode: StorageMode) -> Date? {
        guard let iso = item.expiryByStorageISO8601[mode] else { return nil }
        return ISO8601Helper.formatter.date(from: iso)
    }

    private func storageLabel(_ mode: StorageMode) -> String {
        mode.label
    }

    private func currency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = .current
        return fmt.string(from: NSNumber(value: value)) ?? "—"
    }

    private func expiryColumn(label: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatDate(date))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: ReceiptItem(
            name: "Strawberries",
            quantity: 1,
            purchasedAt: .now,
            defaultStorage: .fridge,
            expiryByStorageISO8601: [.fridge: ISO8601Helper.formatter.string(from: .now.addingTimeInterval(86400))]
        ))
        .environmentObject(AppStore())
    }
}
