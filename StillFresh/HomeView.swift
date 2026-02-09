import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var daysAhead: Int = 2 // 48 hours default
    private let days = Array(1...7)

    @State private var sort: SortOption = .soonestExpiry
    @State private var activeStorages: Set<StorageMode> = Set(StorageMode.allCases) // default: all selected

    @State private var showSavingsDetail = false
    @State private var showLossDetail = false

    private enum SortOption: String, CaseIterable, Identifiable {
        case soonestExpiry = "Soonest expiry"
        case latestExpiry = "Latest expiry"
        case urgency = "Urgency"
        case storage = "Storage"
        case nameAZ = "Name (A–Z)"
        case purchasedNewest = "Purchased (newest)"
        case quantityHigh = "Quantity (high)"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    controlsRow
                    summaryCards
                    expiringList
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("StillFresh")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { store.loadMockDataIfEmpty() }
        }
    }

    private var header: some View {
        ColorfulCard {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "drop.degreesign")
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expiring soon")
                            .font(.headline)
                        Text("Showing the next \(daysAhead) day\(daysAhead == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)

                Divider().opacity(0.15)

                HStack(spacing: 0) {
                    let pantrySelected = activeStorages.contains(.pantry)
                    storageIcon(.pantry, color: .brown, selected: pantrySelected)
                        .overlay(
                            Circle()
                                .stroke(pantrySelected ? Color.brown.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 2)
                                .scaleEffect(pantrySelected ? 1.15 : 0.9)
                                .opacity(pantrySelected ? 0.0 : 0.0)
                                .allowsHitTesting(false)
                                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: pantrySelected)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if pantrySelected { activeStorages.remove(.pantry) } else { activeStorages.insert(.pantry) }
                            }
                        }
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                    let fridgeSelected = activeStorages.contains(.fridge)
                    storageIcon(.fridge, color: .blue, selected: fridgeSelected)
                        .overlay(
                            Circle()
                                .stroke(fridgeSelected ? Color.blue.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 2)
                                .scaleEffect(fridgeSelected ? 1.15 : 0.9)
                                .opacity(fridgeSelected ? 0.0 : 0.0)
                                .allowsHitTesting(false)
                                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: fridgeSelected)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if fridgeSelected { activeStorages.remove(.fridge) } else { activeStorages.insert(.fridge) }
                            }
                        }
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 6)
                    let freezerSelected = activeStorages.contains(.freezer)
                    storageIcon(.freezer, color: .indigo, selected: freezerSelected)
                        .overlay(
                            Circle()
                                .stroke(freezerSelected ? Color.indigo.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 2)
                                .scaleEffect(freezerSelected ? 1.15 : 0.9)
                                .opacity(freezerSelected ? 0.0 : 0.0)
                                .allowsHitTesting(false)
                                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: freezerSelected)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                if freezerSelected { activeStorages.remove(.freezer) } else { activeStorages.insert(.freezer) }
                            }
                        }
                }
            }
        }
    }

    private func ripple(selected: Bool) -> some View {
        Circle()
            .stroke(selected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.15), lineWidth: 2)
            .scaleEffect(selected ? 1.25 : 0.8)
            .opacity(0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: selected)
    }

    private func storageIcon(_ mode: StorageMode, color: Color, selected: Bool) -> some View {
        VStack(spacing: 1) {
            Image(systemName: mode.iconName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(selected ? color : .secondary, selected ? color.opacity(0.3) : Color.secondary.opacity(0.15))
                .font(.system(size: 16, weight: .bold))
            Text(mode.label)
                .font(.caption2)
                .foregroundStyle(selected ? .secondary : .tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .scaleEffect(selected ? 1.0 : 0.96)
        .opacity(selected ? 1.0 : 0.6)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selected)
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(days, id: \.self) { d in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { daysAhead = d }
                    } label: {
                        Text("Next \(d) day\(d == 1 ? "" : "s")")
                    }
                }
            } label: {
                Label("Next \(daysAhead) day\(daysAhead == 1 ? "" : "s")", systemImage: "clock")
            }
            .buttonStyle(.bordered)

            Menu {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { sort = opt }
                    } label: {
                        if opt == sort { Label(opt.rawValue, systemImage: "checkmark") }
                        else { Text(opt.rawValue) }
                    }
                }
            } label: {
                Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private var summaryCards: some View {
        let bucket = store.currentWeekBucket()
        return HStack(spacing: 12) {
            StatTile(
                mainTitle: "Potential savings",
                subtitle: "This week",
                amount: bucket.potential.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                color: .green,
                fixedHeight: 90
            )
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            StatTile(
                mainTitle: "Wasted",
                subtitle: "This week",
                amount: bucket.wasted.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                color: .red,
                fixedHeight: 90
            )
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        // ✅ real spacing (no spacer hacks) so tiles don't "merge" with pills above or list below
        .padding(.top, 0)
        .padding(.bottom, 0)
        // ✅ keep your sheets as-is
        .sheet(isPresented: $showSavingsDetail) { WeeklyDeltaSheet(kind: .savings, current: bucket.potential, items: store.items) }
        .sheet(isPresented: $showLossDetail) { WeeklyDeltaSheet(kind: .loss, current: bucket.wasted, items: store.items) }
    }

    
    // Robust ISO8601 parsing (handles with/without fractional seconds)
    private func parseISO8601(_ s: String) -> Date? {
        if let d = ISO8601Helper.formatter.date(from: s) { return d }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f2.date(from: s)
    }

private var expiringList: some View {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        // Calendar-inclusive window: daysAhead=2 => include today + next 2 days.
        let endExclusive = cal.date(byAdding: .day, value: daysAhead + 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(TimeInterval(daysAhead + 1) * 24 * 3600)

        // Dedup by canonicalKey, but keep the *actual* purchase instance that expires next.
        let grouped: [String: [ReceiptItem]] = Dictionary(grouping: store.items, by: { $0.canonicalKey })

        var representatives: [(ReceiptItem, Date)] = []
        representatives.reserveCapacity(grouped.count)

        for (_, group) in grouped {
            let withDates: [(ReceiptItem, Date)] = group.compactMap { it in
                guard let d = parseISO8601(it.effectiveExpiryISO8601) else { return nil }
                // Only consider items that are unused, in an active storage, and expiring within [startOfToday, endExclusive)
                guard !it.isUsed, activeStorages.contains(it.selectedStorage), d >= startOfToday, d < endExclusive else { return nil }
                return (it, d)
            }
            guard let soonest = withDates.min(by: { $0.1 < $1.1 }) else { continue }
            representatives.append(soonest)
        }

        let expiring = representatives.sorted { a, b in
            switch sort {
            case .soonestExpiry: return a.1 < b.1
            case .latestExpiry: return a.1 > b.1
            case .urgency: return urgencyRank(a.0) < urgencyRank(b.0)
            case .storage: return storageRank(a.0.selectedStorage) < storageRank(b.0.selectedStorage)
            case .nameAZ: return a.0.name.localizedCaseInsensitiveCompare(b.0.name) == .orderedAscending
            case .purchasedNewest: return a.0.purchasedAt > b.0.purchasedAt
            case .quantityHigh: return a.0.quantity > b.0.quantity
            }
        }

        return VStack(alignment: .leading, spacing: 10) {
            if expiring.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("All clear ✨")
                            .font(.headline)
                        Text("No items expiring in the next \(daysAhead) day\(daysAhead == 1 ? "" : "s").")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(expiring, id: \.0.id) { item, date in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        ItemRow(item: item, date: date, onMarkUsed: { markUsed($0) })
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func urgencyRank(_ item: ReceiptItem) -> Int {
        switch item.urgency() {
        case .expired: return 0
        case .soon: return 1
        case .fresh: return 2
        }
    }

    private func storageRank(_ mode: StorageMode) -> Int {
        switch mode {
        case .pantry: return 0
        case .fridge: return 1
        case .freezer: return 2
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    private func isInCurrentWeek(_ date: Date) -> Bool {
        let cal = Calendar.current
        let start = startOfWeek(for: Date())
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return false }
        return (start ... end).contains(date)
    }

    private func isInWeek(of ref: Date, date: Date) -> Bool {
        let cal = Calendar.current
        let start = startOfWeek(for: ref)
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return false }
        return (start ... end).contains(date)
    }

    private var expiringCountForRange: Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let endExclusive = cal.date(byAdding: .day, value: daysAhead + 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(TimeInterval(daysAhead + 1) * 24 * 3600)

        let grouped = Dictionary(grouping: store.items, by: { $0.canonicalKey })
        var representatives: [(ReceiptItem, Date)] = []

        for (_, group) in grouped {
            let withDates: [(ReceiptItem, Date)] = group.compactMap { it in
                guard let d = parseISO8601(it.effectiveExpiryISO8601) else { return nil }
                guard !it.isUsed, activeStorages.contains(it.selectedStorage), d >= startOfToday, d < endExclusive else { return nil }
                return (it, d)
            }
            if let soonest = withDates.min(by: { $0.1 < $1.1 }) {
                representatives.append(soonest)
            }
        }
        return representatives.count
    }

    private var potentialSavingsEstimate: Double {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let endExclusive = cal.date(byAdding: .day, value: daysAhead + 1, to: startOfToday)
            ?? startOfToday.addingTimeInterval(TimeInterval(daysAhead + 1) * 24 * 3600)

        let grouped = Dictionary(grouping: store.items, by: { $0.canonicalKey })
        var representatives: [ReceiptItem] = []

        for (_, group) in grouped {
            let withDates: [(ReceiptItem, Date)] = group.compactMap { it in
                guard let d = parseISO8601(it.effectiveExpiryISO8601) else { return nil }
                guard !it.isUsed, activeStorages.contains(it.selectedStorage), d >= startOfToday, d < endExclusive else { return nil }
                return (it, d)
            }
            if let soonest = withDates.min(by: { $0.1 < $1.1 }) {
                representatives.append(soonest.0)
            }
        }

        let currencySum: Double = representatives.reduce(0) { acc, item in
            if let total = item.totalPrice { return acc + total }
            if let ppu = item.pricePerUnit {
                return acc + (ppu * Double(max(1, item.quantity)))
            }
            return acc
        }
        return currencySum
    }

    private func markUsed(_ item: ReceiptItem) {
        store.toggleUsed(item)
    }
}

struct ItemRow: View {
    @EnvironmentObject private var store: AppStore
    let item: ReceiptItem
    let date: Date
    let onMarkUsed: (ReceiptItem) -> Void

    @State private var showEditDate = false
    @State private var editedDate = Date()

    @State private var showEditQuantity = false
    @State private var editedQuantity: Int = 1

    @State private var showEditItemSheet = false
    @State private var showStoragePicker = false

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack(alignment: .center) {
                        Circle()
                            .fill(storageColor.opacity(0.18))
                            .overlay(
                                Circle()
                                    .stroke(storageColor, lineWidth: 1)
                            )

                        Text(item.iconEmoji)
                            .font(.system(size: 32))

                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: storageIcon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(storageColor)
                            )
                            .offset(x: 20, y: 14)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        // Row 1: item name + per-unit details
                        Text(item.displayName + (item.quantity > 1 ? " ×\(item.quantity)" : ""))
                            .font(.headline)
                            .lineLimit(1)

                        // Row 2: Expires — in X days
                        Text(expiresText(date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Row 3: buy date
                        Text("Bought: \(formatDate(item.purchasedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        editedQuantity = max(1, item.quantity)
                        showEditQuantity = true
                        Haptics.selection()
                    } label: {
                        Text(item.quantityLabel)
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(badgeColor)
                    .buttonStyle(.plain)
                }
                GeometryReader { geo in
                    let fraction = progressFraction()
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 4)
                        Capsule().fill(progressColor()).frame(width: max(0, fraction) * geo.size.width, height: 4)
                    }
                }
                .frame(height: 6)
                .padding(.top, 6)

                HStack {
                    Spacer()

                    if item.isUsed {
                        Label("Used", systemImage: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.green.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(.green.opacity(0.25), lineWidth: 1))
                    } else {
                        Button {
                            onMarkUsed(item)
                            Haptics.selection()
                        } label: {
                            Text("Mark used")
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            Button { showEditItemSheet = true } label: { Label("Edit Item", systemImage: "pencil") }
            Button { showStoragePicker = true } label: { Label("Change Storage", systemImage: "tray.and.arrow.down") }
            Button { primeEditedDate(); showEditDate = true } label: { Label("Edit Expiration", systemImage: "calendar.badge.clock") }
            Divider()
            Button(role: .destructive) { store.removeItem(item); Haptics.notify(.warning) } label: { Label("Delete", systemImage: "trash") }
        }
        .sheet(isPresented: $showStoragePicker) {
            StoragePickerSheet(
                title: "Storage",
                selected: item.selectedStorage,
                onSelect: { updateStorage($0); showStoragePicker = false }
            )
            .presentationDetents([.height(220)])
        }

        .sheet(isPresented: $showEditItemSheet) {
            EditReceiptItemSheet(item: item) { updated in
                guard let idx = store.items.firstIndex(of: item) else { return }
                store.items[idx] = updated
                Haptics.notify(.success)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEditDate) {
            NavigationStack {
                VStack(spacing: 18) {
                    DatePicker("Expiration", selection: $editedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    Text("This overrides AI for this item.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .navigationTitle("Edit Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showEditDate = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { saveOverride(); showEditDate = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEditQuantity) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Stepper(value: $editedQuantity, in: 1...99) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(editedQuantity)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    Text("This updates the quantity for this purchase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(16)
                .navigationTitle("Edit Quantity")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showEditQuantity = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { saveQuantity(); showEditQuantity = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.height(260)])
        }
    }

    private var storageColor: Color {
        switch item.selectedStorage {
        case .pantry: return .brown
        case .fridge: return .blue
        case .freezer: return .indigo
        }
    }

    private var storageIcon: String {
        item.selectedStorage.iconName
    }

    private var badgeColor: Color {
        switch item.urgency() {
        case .expired: return .red
        case .soon: return .orange
        case .fresh: return .secondary
        }
    }

    private func expiresText(_ d: Date) -> String {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let expiryStart = cal.startOfDay(for: d)

        let days = cal.dateComponents([.day], from: todayStart, to: expiryStart).day ?? 0

        if days < 0 { return "Expires — expired" }
        if days == 0 { return "Expires — today" }
        if days == 1 { return "Expires — tomorrow" }
        return "Expires — in \(days) days"
    }

    private func formatDate(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: d)
    }

    private func updateStorage(_ mode: StorageMode) {
        guard let idx = store.items.firstIndex(of: item) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            store.items[idx].selectedStorage = mode
        }
        Haptics.selection()
    }

    private func primeEditedDate() {
        let current = ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601) ?? Date()
        editedDate = current
    }

    private func saveOverride() {
        guard let idx = store.items.firstIndex(of: item) else { return }
        store.items[idx].userOverrideExpiryISO8601 = ISO8601Helper.formatter.string(from: editedDate)
        Haptics.notify(.success)
    }

    private func saveQuantity() {
        guard let idx = store.items.firstIndex(of: item) else { return }
        store.items[idx].quantity = max(1, editedQuantity)
        Haptics.notify(.success)
    }

    private func expiryDate() -> Date? { ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601) }

    private func progressFraction() -> CGFloat {
        guard let end = expiryDate() else { return 0 }
        let start = item.purchasedAt
        let total = end.timeIntervalSince(start)
        if total <= 0 { return 0 }
        let remaining = end.timeIntervalSince(Date())
        let fraction = remaining / total
        return CGFloat(min(1, max(0, fraction)))
    }

    private func progressColor() -> Color {
        switch item.urgency() {
        case .expired: return .red
        case .soon: return .orange
        case .fresh: return .green
        }
    }
}

private struct WeeklyDeltaSheet: View {
    enum Kind { case savings, loss }
    let kind: Kind
    let current: Double
    let items: [ReceiptItem]

    private var now: Date { Date() }

    private func startOfWeek(_ d: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return cal.date(from: comps) ?? cal.startOfDay(for: d)
    }

    private var previousWeekValue: Double {
        let cal = Calendar.current
        let thisStart = startOfWeek(now)
        guard let prevStart = cal.date(byAdding: .day, value: -7, to: thisStart),
              let prevEnd = cal.date(byAdding: .day, value: 7, to: prevStart) else { return 0 }
        let pairs = items.compactMap { item -> (ReceiptItem, Date)? in
            guard let d = ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601) else { return nil }
            return (item, d)
        }
        switch kind {
        case .savings:
            let potentials = pairs.filter { $0.1 >= prevStart && $0.1 < prevEnd && $0.1 >= prevStart }
            return potentials.reduce(0) { acc, pair in
                let it = pair.0
                if let t = it.totalPrice { return acc + t }
                if let ppu = it.pricePerUnit { return acc + ppu * Double(max(1, it.quantity)) }
                return acc
            }
        case .loss:
            let lost = pairs.filter { $0.1 >= prevStart && $0.1 < prevEnd && $0.1 < thisStart }
            return lost.reduce(0) { acc, pair in
                let it = pair.0
                if let t = it.totalPrice { return acc + t }
                if let ppu = it.pricePerUnit { return acc + ppu * Double(max(1, it.quantity)) }
                return acc
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(kind == .savings ? "Potential savings" : "Wasted")
                    .font(.headline)
                HStack(spacing: 12) {
                    GlassCard { Text(current, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).font(.title2.weight(.semibold)) }
                    GlassCard { Text(previousWeekValue, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).font(.title2.weight(.semibold)).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity)

                Chart {
                    BarMark(x: .value("Week", "Prev"), y: .value("Amount", previousWeekValue))
                        .foregroundStyle(kind == .loss ? .red.opacity(0.6) : .green.opacity(0.6))
                    BarMark(x: .value("Week", "This"), y: .value("Amount", current))
                        .foregroundStyle(kind == .loss ? .red : .green)
                }
                .frame(height: 160)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("This vs last week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { } } }
        }
        .presentationDetents([.height(320), .medium])
    }
}


