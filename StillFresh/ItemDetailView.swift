import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var store: AppStore
    let item: ReceiptItem

    private var history: [ReceiptItem] {
        store.items
            .filter { $0.canonicalKey == item.canonicalKey }
            .sorted { $0.purchasedAt > $1.purchasedAt }
    }

    private var purchaseGroupsForThisItem: [PurchaseGroupSummary] {
        let cal = Calendar.current
        let days = Set(history.map { cal.startOfDay(for: $0.purchasedAt) })

        return days
            .map { day in
                let groupItems = store.items.filter { cal.isDate($0.purchasedAt, inSameDayAs: day) }
                let thisItemInGroup = groupItems.filter { $0.canonicalKey == item.canonicalKey }
                return PurchaseGroupSummary(
                    day: day,
                    totalItems: groupItems.count,
                    totalQuantity: groupItems.reduce(0) { $0 + max(1, $1.quantity) },
                    thisItemCount: thisItemInGroup.count,
                    thisItemQuantity: thisItemInGroup.reduce(0) { $0 + max(1, $1.quantity) }
                )
            }
            .sorted { $0.day > $1.day }
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
                if let ppu = item.pricePerUnit { detailRow("Price / unit", currency(ppu)) }
                if let total = item.totalPrice { detailRow("Total price", currency(total)) }
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

            // ✅ Purchase history section (NO PurchaseItemsView usage)
            Section("Purchase history") {
                if purchaseGroupsForThisItem.isEmpty {
                    Text("No purchase history found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(purchaseGroupsForThisItem) { g in
                        NavigationLink {
                            // Show all items from the purchase group (same-day)
                            AllItemsListView(
                                title: "Purchase • \(formatDate(g.day))",
                                filter: { it in Calendar.current.isDate(it.purchasedAt, inSameDayAs: g.day) },
                                onOpenItem: { _ in
                                    // Smart nav is handled by AllItemsView’s bounded stack.
                                    // If user wants to open another item, they can from there.
                                }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Purchased on \(formatDate(g.day))")
                                    .font(.subheadline.weight(.semibold))

                                HStack(spacing: 10) {
                                    Text("Purchase group: \(g.totalItems) items")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if g.totalQuantity > g.totalItems {
                                        Text("• Qty \(g.totalQuantity)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                HStack(spacing: 10) {
                                    Text("This item in group: \(g.thisItemCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if g.thisItemQuantity > g.thisItemCount {
                                        Text("• Qty \(g.thisItemQuantity)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ✅ Back to All root (works via AllItemsView listener)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NotificationCenter.default.post(name: .sfPopToAllRoot, object: nil)
                    Haptics.selection()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .accessibilityLabel("Back to All Items")
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 12) }
    }

    private struct PurchaseGroupSummary: Identifiable {
        let id = UUID()
        let day: Date
        let totalItems: Int
        let totalQuantity: Int
        let thisItemCount: Int
        let thisItemQuantity: Int
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

    private func storageLabel(_ mode: StorageMode) -> String { mode.label }

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

