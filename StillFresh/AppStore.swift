import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var sessions: [ReceiptSession] = []
    @Published var items: [ReceiptItem] = []
    @Published var snackbar: SnackbarState?

    func loadMockDataIfEmpty() {
        guard items.isEmpty else { return }
        let now = Date()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func iso(_ date: Date) -> String { fmt.string(from: date) }

        let sample: [ReceiptItem] = [
            ReceiptItem(name: "Strawberries", quantity: 1, purchasedAt: now.addingTimeInterval(-1*24*3600),
                        defaultStorage: .fridge,
                        expiryByStorageISO8601: [.pantry: iso(now.addingTimeInterval(6*3600)),
                                                .fridge: iso(now.addingTimeInterval(48*3600)),
                                                .freezer: iso(now.addingTimeInterval(14*24*3600))],
                        pricePerUnit: 3.99, totalPrice: 3.99),
            ReceiptItem(name: "Chicken Breast", quantity: 1, purchasedAt: now.addingTimeInterval(-2*24*3600),
                        defaultStorage: .fridge,
                        expiryByStorageISO8601: [.pantry: iso(now.addingTimeInterval(2*3600)),
                                                .fridge: iso(now.addingTimeInterval(36*3600)),
                                                .freezer: iso(now.addingTimeInterval(90*24*3600))],
                        pricePerUnit: 5.49, totalPrice: 10.98),
            ReceiptItem(name: "Bananas", quantity: 6, purchasedAt: now.addingTimeInterval(-3*24*3600),
                        defaultStorage: .pantry,
                        expiryByStorageISO8601: [.pantry: iso(now.addingTimeInterval(72*3600)),
                                                .fridge: iso(now.addingTimeInterval(6*24*3600)),
                                                .freezer: iso(now.addingTimeInterval(60*24*3600))],
                        pricePerUnit: 0.29, totalPrice: 1.74),
        ]
        self.items = sample
    }

    func upsertItems(from aiResponse: AIReceiptResponse) {
        let mapped: [ReceiptItem] = aiResponse.items.compactMap { item in
            let storage = StorageMode(rawValue: item.default_storage) ?? .pantry
            let by: [StorageMode: String] = [
                .pantry: item.expiry.pantry,
                .fridge: item.expiry.fridge,
                .freezer: item.expiry.freezer
            ]
            return ReceiptItem(name: item.name,
                               quantity: item.quantity ?? 1,
                               purchasedAt: Date(),
                               defaultStorage: storage,
                               expiryByStorageISO8601: by)
        }

        // MVP: flatten into global list.
        // Later: keep per-receipt sessions and duplicate detection.
        self.items.append(contentsOf: mapped)
    }

    func removeItem(_ item: ReceiptItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items.remove(at: idx)

        snackbar = SnackbarState(
            message: "Removed “\(item.name)”",
            actionTitle: "Undo",
            action: { [weak self] in
                guard let self else { return }
                self.items.insert(item, at: min(idx, self.items.count))
                // Dismiss snackbar immediately after undo
                self.snackbar = nil
            }
        )
    }

    func removeItems(_ itemsToRemove: [ReceiptItem]) {
        guard !itemsToRemove.isEmpty else { return }

        if itemsToRemove.count == 1, let only = itemsToRemove.first {
            // Delegate to single-item removal to keep naming and undo behavior
            removeItem(only)
            return
        }

        // Capture original indices to restore order on undo
        let indexed: [(Int, ReceiptItem)] = itemsToRemove.compactMap { item in
            guard let idx = items.firstIndex(of: item) else { return nil }
            return (idx, item)
        }.sorted { $0.0 < $1.0 }

        // Remove items
        for (_, item) in indexed.reversed() {
            if let idx = items.firstIndex(of: item) {
                items.remove(at: idx)
            }
        }

        // Show snackbar for multiple delete (no bold here, SnackbarView controls style)
        snackbar = SnackbarState(
            message: "Deleted multiple items",
            actionTitle: "Undo",
            action: { [weak self] in
                guard let self else { return }
                for (idx, item) in indexed {
                    let insertIndex = min(idx, self.items.count)
                    self.items.insert(item, at: insertIndex)
                }
                self.snackbar = nil
            }
        )
    }

    func showUndoSnackbar(_ message: String, undo: @escaping () -> Void) {
        snackbar = SnackbarState(message: message, actionTitle: "Undo", action: { [weak self] in
            undo()
            self?.snackbar = nil
        })
    }
}

struct SnackbarState: Identifiable {
    let id = UUID()
    let message: String
    let actionTitle: String
    let action: () -> Void
}
