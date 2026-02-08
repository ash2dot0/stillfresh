import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var daysAhead: Int = 2 // 48 hours default
    private let days = Array(1...7)

    @State private var sort: SortOption = .soonestExpiry
    @State private var activeStorages: Set<StorageMode> = Set(StorageMode.allCases) // default: all selected

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
        HStack(spacing: 10) {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Needs attention")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(expiringCountForRange)")
                            .font(.title3.weight(.semibold))
                        Text("items")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Potential savings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(potentialSavingsEstimate, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                            .font(.title3.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var expiringList: some View {
        let cutoff = Date().addingTimeInterval(TimeInterval(daysAhead) * 24 * 3600)

        // Dedup by canonicalKey, but keep the *actual* purchase instance that expires next.
        let grouped: [String: [ReceiptItem]] = Dictionary(grouping: store.items, by: { $0.canonicalKey })

        var representatives: [(ReceiptItem, Date)] = []
        representatives.reserveCapacity(grouped.count)

        for (_, group) in grouped {
            let withDates: [(ReceiptItem, Date)] = group.compactMap { it in
                guard let d = ISO8601Helper.formatter.date(from: it.effectiveExpiryISO8601) else { return nil }
                return (it, d)
            }
            guard let soonest = withDates.min(by: { $0.1 < $1.1 }) else { continue }
            if soonest.1 <= cutoff { representatives.append(soonest) }
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

        let filtered = expiring.filter { item, _ in activeStorages.contains(item.selectedStorage) }

        return VStack(alignment: .leading, spacing: 10) {
            if filtered.isEmpty {
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
                ForEach(filtered, id: \.0.id) { item, date in
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

    private var expiringCountForRange: Int {
        let cutoff = Date().addingTimeInterval(TimeInterval(daysAhead) * 24 * 3600)
        let grouped = Dictionary(grouping: store.items, by: { $0.canonicalKey })
        var representatives: [(ReceiptItem, Date)] = []
        for (_, group) in grouped {
            let withDates: [(ReceiptItem, Date)] = group.compactMap { it in
                guard let d = ISO8601Helper.formatter.date(from: it.effectiveExpiryISO8601) else { return nil }
                return (it, d)
            }
            if let soonest = withDates.min(by: { $0.1 < $1.1 }), soonest.1 <= cutoff {
                representatives.append(soonest)
            }
        }
        return representatives.count
    }

    private var potentialSavingsEstimate: Double {
        let cutoff = Date().addingTimeInterval(TimeInterval(daysAhead) * 24 * 3600)
        let grouped = Dictionary(grouping: store.items, by: { $0.canonicalKey })
        var representatives: [ReceiptItem] = []
        for (_, group) in grouped {
            let withDates: [(ReceiptItem, Date)] = group.compactMap { it in
                guard let d = ISO8601Helper.formatter.date(from: it.effectiveExpiryISO8601) else { return nil }
                return (it, d)
            }
            if let soonest = withDates.min(by: { $0.1 < $1.1 }), soonest.1 <= cutoff {
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
        guard let idx = store.items.firstIndex(of: item) else { return }
        store.items.remove(at: idx)
        store.showUndoSnackbar("Marked used “\(item.name)”") {
            store.items.insert(item, at: min(idx, store.items.count))
        }
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
                    Button("Mark used") {
                        onMarkUsed(item)
                        Haptics.selection()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
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
        let now = Date()
        let secs = d.timeIntervalSince(now)
        let days = Int(ceil(secs / (24*3600)))

        if secs < 0 {
            return "Expires — expired"
        }
        if days <= 0 {
            return "Expires — today"
        }
        if days == 1 {
            return "Expires — in 1 day"
        }
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

struct StoragePickerSheet: View {
    let title: String
    let selected: StorageMode
    let onSelect: (StorageMode) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.top, 8)

            HStack(spacing: 12) {
                storageButton(.pantry)
                storageButton(.fridge)
                storageButton(.freezer)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.bottom, 10)
    }

    private func storageButton(_ mode: StorageMode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 22, weight: .bold))
                Text(mode.label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected == mode ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected == mode ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
