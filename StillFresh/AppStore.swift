import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var sessions: [ReceiptSession] = []
    @Published var items: [ReceiptItem] = []
    @Published var snackbar: SnackbarState?

    // MARK: - Weekly stats (single source of truth)

    struct WeekBucket: Identifiable, Equatable {
        var id: Date { weekStart }
        let weekStart: Date
        let potential: Double     // not used yet, expires this week (>= today)
        let wasted: Double        // expired (before today) and not used
        let saved: Double         // marked used (counts in the item's expiry week)
    }

    private var isoCal: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }

    func startOfWeekMonday(for date: Date) -> Date {
        isoCal.date(from: isoCal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
    }

    // MARK: - ISO parsing + local-calendar day normalization (timezone-safe)

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

    /// Convert an absolute ISO date into "the same YYYY-MM-DD" in device local time, then return local start-of-day.
    /// This prevents UTC midnight (or any timezone offset) from shifting the calendar day.
    private func localDayStartPreservingUTCDate(_ absolute: Date) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!

        let ymd = utc.dateComponents([.year, .month, .day], from: absolute)

        var local = Calendar.current
        local.timeZone = .current

        var noon = DateComponents()
        noon.year = ymd.year
        noon.month = ymd.month
        noon.day = ymd.day
        noon.hour = 12 // DST-safe anchor

        guard let localNoon = local.date(from: noon) else { return nil }
        return local.startOfDay(for: localNoon)
    }

    /// Expiry day (start-of-day) in device local timezone, treating expiry as a calendar date.
    private func expiryDayStartLocal(for item: ReceiptItem) -> Date? {
        guard let abs = parseISO8601(item.effectiveExpiryISO8601) else { return nil }
        return localDayStartPreservingUTCDate(abs)
    }

    // MARK: - Weekly buckets

    func weeklyBuckets(weeksBack: Int = 8, now: Date = Date()) -> [WeekBucket] {
        let currentWeekStart = startOfWeekMonday(for: now)
        let weeks: [Date] = (0..<weeksBack).compactMap { i in
            isoCal.date(byAdding: .weekOfYear, value: -i, to: currentWeekStart)
        }.sorted()

        var byWeek: [Date: WeekBucket] = Dictionary(uniqueKeysWithValues: weeks.map {
            ($0, WeekBucket(weekStart: $0, potential: 0, wasted: 0, saved: 0))
        })

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)

        for item in items {
            guard let expiryDayStart = expiryDayStartLocal(for: item) else { continue }

            // Bucket by expiry week (based on local calendar day)
            let ws = startOfWeekMonday(for: expiryDayStart)
            guard var bucket = byWeek[ws] else { continue }

            let cost = item.effectiveTotalCost

            if item.isUsed {
                bucket = WeekBucket(
                    weekStart: bucket.weekStart,
                    potential: bucket.potential,
                    wasted: bucket.wasted,
                    saved: bucket.saved + cost
                )
            } else if expiryDayStart < todayStart {
                // ✅ Expired only if expiry day is BEFORE today
                bucket = WeekBucket(
                    weekStart: bucket.weekStart,
                    potential: bucket.potential,
                    wasted: bucket.wasted + cost,
                    saved: bucket.saved
                )
            } else {
                // ✅ Today or future => potential
                bucket = WeekBucket(
                    weekStart: bucket.weekStart,
                    potential: bucket.potential + cost,
                    wasted: bucket.wasted,
                    saved: bucket.saved
                )
            }

            byWeek[ws] = bucket
        }

        return weeks.compactMap { byWeek[$0] }
    }

    func currentWeekBucket(now: Date = Date()) -> WeekBucket {
        let ws = startOfWeekMonday(for: now)
        let bucket = weeklyBuckets(weeksBack: 1, now: now).first
        return bucket ?? WeekBucket(weekStart: ws, potential: 0, wasted: 0, saved: 0)
    }

    // MARK: - Item mutations

    func toggleUsed(_ item: ReceiptItem, now: Date = Date()) {
        guard let idx = items.firstIndex(of: item) else { return }
        let wasUsed = items[idx].isUsed
        items[idx].isUsed.toggle()
        items[idx].usedAt = items[idx].isUsed ? now : nil

        let message = items[idx].isUsed ? "Marked used “\(item.name)”" : "Marked unused “\(item.name)”"
        showUndoSnackbar(message) { [weak self] in
            guard let self else { return }
            guard let j = self.items.firstIndex(where: { $0.id == item.id }) else { return }
            self.items[j].isUsed = wasUsed
            self.items[j].usedAt = wasUsed ? now : nil
        }
    }

    // MARK: - Mock data

    func loadMockDataIfEmpty() {
        guard items.isEmpty else { return }
        let now = Date()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func iso(_ date: Date) -> String { fmt.string(from: date) }

        func expiryMap(purchasedAt: Date,
                       pantryHours: Double,
                       fridgeDays: Double,
                       freezerDays: Double) -> [StorageMode: String] {
            [
                .pantry: iso(purchasedAt.addingTimeInterval(pantryHours * 3600)),
                .fridge: iso(purchasedAt.addingTimeInterval(fridgeDays * 24 * 3600)),
                .freezer: iso(purchasedAt.addingTimeInterval(freezerDays * 24 * 3600))
            ]
        }

        func addReceipt(purchasedAt: Date, _ items: [ReceiptItem]) {
            self.items.append(contentsOf: items.map { it in
                var copy = it
                copy.purchasedAt = purchasedAt
                return copy
            })
        }

        self.items = []

        let purchaseDates: [Date] = [
            now.addingTimeInterval(-1 * 24 * 3600),
            now.addingTimeInterval(-4 * 24 * 3600),
            now.addingTimeInterval(-9 * 24 * 3600),
            now.addingTimeInterval(-16 * 24 * 3600),
            now.addingTimeInterval(-23 * 24 * 3600),
            now.addingTimeInterval(-31 * 24 * 3600),
            now.addingTimeInterval(-39 * 24 * 3600),
            now.addingTimeInterval(-46 * 24 * 3600)
        ]

        addReceipt(purchasedAt: purchaseDates[0], [
            ReceiptItem(name: "Strawberries", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[0], pantryHours: 8, fridgeDays: 1, freezerDays: 14),
                        pricePerUnit: 3.99, totalPrice: 3.99,
                        isUsed: true),
            ReceiptItem(name: "Baby Spinach", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[0], pantryHours: 6, fridgeDays: 4, freezerDays: 40),
                        pricePerUnit: 3.49, totalPrice: 3.49),
            ReceiptItem(name: "Greek Yogurt", quantity: 2, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[0], pantryHours: 2, fridgeDays: 10, freezerDays: 60),
                        pricePerUnit: 1.39, totalPrice: 2.78),
            ReceiptItem(name: "Bananas", quantity: 6, defaultStorage: .pantry,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[0], pantryHours: 72, fridgeDays: 6, freezerDays: 60),
                        pricePerUnit: 0.29, totalPrice: 1.74)
        ])

        if let first = self.items.firstIndex(where: { $0.name == "Baby Spinach" && $0.purchasedAt == purchaseDates[0] }) {
            self.items[first].isUsed = true
            self.items[first].usedAt = now
        }

        addReceipt(purchasedAt: purchaseDates[1], [
            ReceiptItem(name: "Chicken Breast", quantity: 2, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[1], pantryHours: 2, fridgeDays: 2, freezerDays: 120),
                        pricePerUnit: 5.49, totalPrice: 21.96),
            ReceiptItem(name: "Fresh Salmon", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[1], pantryHours: 1.5, fridgeDays: 2, freezerDays: 90),
                        pricePerUnit: 10.99, totalPrice: 10.99),
            ReceiptItem(name: "Avocados", quantity: 3, defaultStorage: .pantry,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[1], pantryHours: 96, fridgeDays: 7, freezerDays: 60),
                        pricePerUnit: 1.49, totalPrice: 4.47),
            ReceiptItem(name: "Grapes", quantity: 3, defaultStorage: .pantry,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[1], pantryHours: 200, fridgeDays: 7, freezerDays: 60),
                        pricePerUnit: 1.49, totalPrice: 4.47),
            ReceiptItem(name: "Sourdough Bread", quantity: 1, defaultStorage: .pantry,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[1], pantryHours: 72, fridgeDays: 10, freezerDays: 45),
                        pricePerUnit: 4.99, totalPrice: 4.99)
        ])

        addReceipt(purchasedAt: purchaseDates[2], [
            ReceiptItem(name: "Raspberries", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[2], pantryHours: 6, fridgeDays: 2, freezerDays: 21),
                        pricePerUnit: 4.49, totalPrice: 4.49),
            ReceiptItem(name: "Eggs", quantity: 12, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[2], pantryHours: 6, fridgeDays: 21, freezerDays: 90),
                        pricePerUnit: 0.28, totalPrice: 3.36),
            ReceiptItem(name: "Grape Tomatoes", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[2], pantryHours: 24, fridgeDays: 5, freezerDays: 60),
                        pricePerUnit: 2.99, totalPrice: 2.99),
            ReceiptItem(name: "Ground Beef", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[2], pantryHours: 2, fridgeDays: 1.5, freezerDays: 120),
                        pricePerUnit: 6.99, totalPrice: 6.99)
        ])

        if let idx = self.items.firstIndex(where: { $0.name == "Raspberries" && $0.purchasedAt == purchaseDates[2] }) {
            self.items[idx].isUsed = true
            self.items[idx].usedAt = now
        }

        addReceipt(purchasedAt: purchaseDates[3], [
            ReceiptItem(name: "Mixed Greens", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[3], pantryHours: 6, fridgeDays: 4, freezerDays: 30),
                        pricePerUnit: 3.79, totalPrice: 3.79),
            ReceiptItem(name: "Milk", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[3], pantryHours: 2, fridgeDays: 7, freezerDays: 30),
                        pricePerUnit: 4.29, totalPrice: 4.29,
                        isUsed: true,
                        usedAt: now),
            ReceiptItem(name: "Cooked Deli Turkey", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[3], pantryHours: 1.5, fridgeDays: 5, freezerDays: 60),
                        pricePerUnit: 7.49, totalPrice: 7.49),
            ReceiptItem(name: "Blueberries", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[3], pantryHours: 6, fridgeDays: 5, freezerDays: 28),
                        pricePerUnit: 3.99, totalPrice: 3.99)
        ])

        addReceipt(purchasedAt: purchaseDates[4], [
            ReceiptItem(name: "Cottage Cheese", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[4], pantryHours: 2, fridgeDays: 9, freezerDays: 45),
                        pricePerUnit: 3.49, totalPrice: 3.49),
            ReceiptItem(name: "Broccoli", quantity: 2, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[4], pantryHours: 8, fridgeDays: 6, freezerDays: 60),
                        pricePerUnit: 1.79, totalPrice: 3.58),
            ReceiptItem(name: "Fresh Mozzarella", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[4], pantryHours: 1.5, fridgeDays: 6, freezerDays: 30),
                        pricePerUnit: 5.99, totalPrice: 5.99)
        ])

        addReceipt(purchasedAt: purchaseDates[5], [
            ReceiptItem(name: "Chicken Thighs", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[5], pantryHours: 2, fridgeDays: 2, freezerDays: 150),
                        pricePerUnit: 4.99, totalPrice: 9.98),
            ReceiptItem(name: "Romaine Lettuce", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[5], pantryHours: 6, fridgeDays: 5, freezerDays: 30),
                        pricePerUnit: 2.49, totalPrice: 2.49),
            ReceiptItem(name: "Cilantro", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[5], pantryHours: 6, fridgeDays: 6, freezerDays: 30),
                        pricePerUnit: 0.99, totalPrice: 0.99)
        ])

        addReceipt(purchasedAt: purchaseDates[6], [
            ReceiptItem(name: "Beef Steak", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[6], pantryHours: 2, fridgeDays: 2, freezerDays: 180),
                        pricePerUnit: 12.99, totalPrice: 12.99),
            ReceiptItem(name: "Mushrooms", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[6], pantryHours: 12, fridgeDays: 7, freezerDays: 90),
                        pricePerUnit: 2.99, totalPrice: 2.99),
            ReceiptItem(name: "Cheddar Cheese", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[6], pantryHours: 4, fridgeDays: 35, freezerDays: 180),
                        pricePerUnit: 4.79, totalPrice: 4.79)
        ])

        addReceipt(purchasedAt: purchaseDates[7], [
            ReceiptItem(name: "Fresh Shrimp", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[7], pantryHours: 1.0, fridgeDays: 1.5, freezerDays: 120),
                        pricePerUnit: 11.49, totalPrice: 11.49),
            ReceiptItem(name: "Spinach Tortellini", quantity: 1, defaultStorage: .fridge,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[7], pantryHours: 2, fridgeDays: 7, freezerDays: 90),
                        pricePerUnit: 5.49, totalPrice: 5.49),
            ReceiptItem(name: "Apples", quantity: 5, defaultStorage: .pantry,
                        expiryByStorageISO8601: expiryMap(purchasedAt: purchaseDates[7], pantryHours: 10 * 24, fridgeDays: 30, freezerDays: 120),
                        pricePerUnit: 0.89, totalPrice: 4.45)
        ])
    }

    // MARK: - AI ingestion

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

        self.items.append(contentsOf: mapped)
    }

    // MARK: - Deletion + snackbar

    func removeItem(_ item: ReceiptItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items.remove(at: idx)

        snackbar = SnackbarState(
            message: "Removed “\(item.name)”",
            actionTitle: "Undo",
            action: { [weak self] in
                guard let self else { return }
                self.items.insert(item, at: min(idx, self.items.count))
                self.snackbar = nil
            }
        )
    }

    func removeItems(_ itemsToRemove: [ReceiptItem]) {
        guard !itemsToRemove.isEmpty else { return }

        if itemsToRemove.count == 1, let only = itemsToRemove.first {
            removeItem(only)
            return
        }

        let indexed: [(Int, ReceiptItem)] = itemsToRemove.compactMap { item in
            guard let idx = items.firstIndex(of: item) else { return nil }
            return (idx, item)
        }.sorted { $0.0 < $1.0 }

        for (_, item) in indexed.reversed() {
            if let idx = items.firstIndex(of: item) {
                items.remove(at: idx)
            }
        }

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

