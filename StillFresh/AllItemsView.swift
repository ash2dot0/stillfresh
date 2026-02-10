import SwiftUI
import Charts

// MARK: - Smart + bounded navigation for All tab

private enum AllNav: Hashable {
    case purchases
    case allItems
    case usedItems
    case expiredItems
    case weeklyProgress
    case purchaseDay(Date)      // startOfDay date
    case item(UUID)             // ReceiptItem.ID assumed UUID
}

extension Notification.Name {
    static let sfPopToAllRoot = Notification.Name("sf_popToAllRoot")
}

// MARK: - Entry (All tab root)

struct AllItemsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var showSettings = false
    @State private var searchText: String = ""

    // Typed stack lets us cap/replace navigation so it never grows endlessly
    @State private var navStack: [AllNav] = []

    @State private var timeTick = Date()

    @State private var dailyTimer: Timer? = nil

    // 0 = System, 1 = Light, 2 = Dark
    @AppStorage("sf_appearance") private var appearanceRaw: Int = 0
    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    private var expiredCount: Int {
        store.items.filter { $0.urgency() == .expired && !$0.isUsed }.count
    }
    private var nonExpiredCount: Int {
        store.items.filter { $0.urgency() != .expired && !$0.isUsed }.count
    }
    private var usedCount: Int {
        store.items.filter { $0.isUsed }.count
    }

    private var globalSearchResults: [ReceiptItem] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return store.items.filter {
            $0.name.lowercased().contains(q) ||
            $0.displayName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack(path: $navStack) {
            mainList
                .navigationTitle("All Items")
                .toolbar {
                    // ✅ Settings only on the main All tab root
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .searchable(text: $searchText, prompt: "Search all items")
                .navigationDestination(for: AllNav.self) { dest in
                    switch dest {
                    case .purchases:
                        PurchasesView(
                            onSelectPurchaseDay: { day in
                                setStack([.purchases, .purchaseDay(day)])
                            }
                        )
                        .toolbar { backToAllToolbar }

                    case .allItems:
                        AllItemsListView(
                            title: "Current Items",
                            filter: { $0.urgency() != .expired && !$0.isUsed },
                            onOpenItem: { id in
                                setStack([.allItems, .item(id)])
                            }
                        )

                    case .usedItems:
                        AllItemsListView(
                            title: "Used Items",
                            filter: { $0.isUsed },
                            onOpenItem: { id in
                                setStack([.usedItems, .item(id)])
                            }
                        )

                    case .expiredItems:
                        AllItemsListView(
                            title: "Expired",
                            filter: { $0.urgency() == .expired && !$0.isUsed },
                            onOpenItem: { id in
                                setStack([.expiredItems, .item(id)])
                            }
                        )

                    case .weeklyProgress:
                        WeeklyProgressView()
                            .toolbar { backToAllToolbar }

                    case .purchaseDay(let day):
                        AllItemsListView(
                            title: purchaseTitle(for: day),
                            filter: { item in Calendar.current.isDate(item.purchasedAt, inSameDayAs: day) },
                            onOpenItem: { id in
                                setStack([.purchases, .purchaseDay(day), .item(id)])
                            }
                        )

                    case .item(let id):
                        if let item = store.items.first(where: { $0.id == id }) {
                            ItemDetailView(item: item)
                                .toolbar { backToAllToolbar }
                        } else {
                            ContentUnavailableView("Item not found", systemImage: "exclamationmark.triangle")
                                .toolbar { backToAllToolbar }
                        }
                    }
                }
        }
        .preferredColorScheme(preferredScheme)
        .onReceive(NotificationCenter.default.publisher(for: .sfPopToAllRoot)) { _ in
            navStack.removeAll()
            searchText = ""
        }
        .onAppear { scheduleMidnightTick() }
        .onDisappear { dailyTimer?.invalidate() }
    }

    // MARK: - Smart navigation helpers

    private func setStack(_ newStack: [AllNav]) {
        navStack = newStack
    }

    private func purchaseTitle(for day: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: day)
    }

    @ToolbarContentBuilder
    private var backToAllToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                navStack.removeAll()
                searchText = ""
                Haptics.selection()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .accessibilityLabel("Back to All Items")
        }
    }

    // MARK: - Root list

    private var mainList: some View {
        List {
            if isSearching {
                searchResultsSection
            } else {
                rootOptionsSection
            }
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(10)
        .id(timeTick)
    }

    @ViewBuilder
    private var rootOptionsSection: some View {
        Section {
            // ✅ Entire row tappable
            Button {
                setStack([.purchases])
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "cart")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purchases").font(.headline)
                        Text("Grouped by purchase date")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ✅ Entire row tappable
            Button {
                setStack([.allItems])
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current items").font(.headline)
                        Text("Browse everything")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if nonExpiredCount > 0 {
                        Text("\(nonExpiredCount)")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ✅ Entire row tappable
            Button {
                setStack([.usedItems])
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Used items").font(.headline)
                        Text("Items you've marked as used")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if usedCount > 0 {
                        Text("\(usedCount)")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ✅ Entire row tappable
            Button {
                setStack([.expiredItems])
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.octagon")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expired items").font(.headline)
                        Text("Already wasted this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if expiredCount > 0 {
                        Text("\(expiredCount)")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ✅ Entire row tappable
            Button {
                setStack([.weeklyProgress])
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly progress").font(.headline)
                        Text("Saved vs lost over time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        let results = globalSearchResults
        if results.isEmpty {
            ContentUnavailableView("No results", systemImage: "magnifyingglass")
                .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(results, id: \.id) { item in
                    Button {
                        setStack([.item(item.id)])
                    } label: {
                        AllItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.removeItem(item) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func secondsUntilNextLocalMidnight(from date: Date = Date()) -> TimeInterval {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        if let nextMidnight = cal.date(byAdding: .day, value: 1, to: startOfDay) {
            return nextMidnight.timeIntervalSince(date)
        }
        return 24 * 60 * 60
    }

    private func scheduleMidnightTick() {
        // Invalidate existing timer
        dailyTimer?.invalidate()

        let delay = secondsUntilNextLocalMidnight()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak dailyTimer = dailyTimer] in
            // Fire tick at midnight
            timeTick = Date()
            // Schedule repeating every 24 hours thereafter
            self.dailyTimer?.invalidate()
            self.dailyTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
                timeTick = Date()
            }
            RunLoop.main.add(self.dailyTimer!, forMode: .common)
        }
    }
}

// MARK: - Purchases list

private struct PurchasesView: View {
    @EnvironmentObject private var store: AppStore
    let onSelectPurchaseDay: (Date) -> Void

    @State private var showDeleteConfirm = false
    @State private var pendingDeleteDay: Date? = nil

    var body: some View {
        List {
            if purchases.isEmpty {
                ContentUnavailableView("No purchases yet", systemImage: "cart")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(purchases) { purchase in
                    Button {
                        onSelectPurchaseDay(purchase.day)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Purchased on \(dateLabel(purchase.day))")
                                .font(.headline)

                            HStack(spacing: 10) {
                                Label("\(purchase.itemCount) items", systemImage: "tray.full")
                                    .labelStyle(.titleAndIcon)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if purchase.totalQuantity > purchase.itemCount {
                                    Text("•  Qty \(purchase.totalQuantity)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeleteDay = purchase.day
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Purchase", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(2)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Purchases")
        .alert("Delete entire purchase?", isPresented: $showDeleteConfirm, presenting: pendingDeleteDay) { day in
            Button("Delete", role: .destructive) {
                let cal = Calendar.current
                let dayStart = cal.startOfDay(for: day)
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
                let itemsToDelete = store.items.filter { item in
                    item.purchasedAt >= dayStart && item.purchasedAt < dayEnd
                }
                store.removeItems(itemsToDelete)
                Haptics.notify(.success)
                pendingDeleteDay = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteDay = nil
            }
        } message: { day in
            Text("This will permanently delete all items purchased on \(dateLabel(day)).")
        }
    }

    private struct PurchaseGroup: Identifiable {
        let id: Date
        let day: Date
        let itemCount: Int
        let totalQuantity: Int
    }

    private var purchases: [PurchaseGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: store.items) { cal.startOfDay(for: $0.purchasedAt) }
        return grouped
            .map { (day, items) in
                PurchaseGroup(
                    id: day,
                    day: day,
                    itemCount: items.count,
                    totalQuantity: items.reduce(0) { $0 + max(1, $1.quantity) }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private func dateLabel(_ day: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: day)
    }
}

// MARK: - Reused list UI (All items + Purchase day items)

struct AllItemsListView: View {
    @EnvironmentObject private var store: AppStore

    let title: String
    let filter: ((ReceiptItem) -> Bool)?
    let onOpenItem: (UUID) -> Void

    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var searchText: String = ""
    @State private var timeTick = Date()

    @State private var dailyTimer: Timer? = nil

    enum SortOption: String, CaseIterable, Identifiable {
        case purchaseDate = "Purchase date"
        case name = "Name"
        case expiry = "Expiry"
        case price = "Price"
        case storage = "Storage"
        var id: String { rawValue }
    }
    @State private var sort: SortOption = .expiry

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        List(selection: isEditing ? $selection : .constant([])) {
            ForEach(displayedItems, id: \.id) { item in
                row(for: item)
                    .tag(item.id)
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
        .listRowSpacing(2)
        .id(timeTick)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(title)
        .toolbar { toolbarContent }
        .searchable(text: $searchText)
        .environment(\.editMode, $editMode)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isEditing {
                MinimalSelectionBar(
                    selectedCount: selection.count,
                    onClear: {
                        selection.removeAll()
                        Haptics.selection()
                    },
                    onDelete: { deleteSelected() }
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.clear)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { 
            selection.removeAll()
            scheduleMidnightTick()
        }
        .onChange(of: editMode) { _, newMode in
            if !newMode.isEditing { selection.removeAll() }
        }
        .onChange(of: store.items) { _, _ in
            let currentIDs = Set(store.items.map(\.id))
            selection = selection.intersection(currentIDs)
        }
        .onDisappear {
            dailyTimer?.invalidate()
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isEditing)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selection.count)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(isEditing ? "Done" : "Edit") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    editMode = isEditing ? .inactive : .active
                    if !editMode.isEditing { selection.removeAll() }
                }
                Haptics.selection()
            }
            .fontWeight(.semibold)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(SortOption.allCases) { opt in
                    Button {
                        sort = opt
                        Haptics.selection()
                    } label: {
                        if opt == sort { Label(opt.rawValue, systemImage: "checkmark") }
                        else { Text(opt.rawValue) }
                    }
                }
            } label: {
                Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
            }
        }
    }

    @ViewBuilder
    private func row(for item: ReceiptItem) -> some View {
        if isEditing {
            AllItemRow(item: item)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
        } else {
            Button {
                onOpenItem(item.id)
            } label: {
                AllItemRow(item: item)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.removeItem(item) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = offsets.map { displayedItems[$0] }
        store.removeItems(items)
        selection.removeAll()
    }

    private func deleteSelected() {
        let items = displayedItems.filter { selection.contains($0.id) }
        guard !items.isEmpty else { return }
        store.removeItems(items)
        selection.removeAll()
        Haptics.notify(.success)
    }

    private var displayedItems: [ReceiptItem] {
        var items = store.items
        if let filter { items = items.filter(filter) }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            items = items.filter {
                $0.name.lowercased().contains(q) ||
                $0.displayName.lowercased().contains(q)
            }
        }

        switch sort {
        case .purchaseDate:
            items.sort { $0.purchasedAt > $1.purchasedAt }
        case .name:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .expiry:
            items.sort {
                (ISO8601Helper.formatter.date(from: $0.effectiveExpiryISO8601) ?? .distantFuture) <
                (ISO8601Helper.formatter.date(from: $1.effectiveExpiryISO8601) ?? .distantFuture)
            }
        case .price:
            items.sort { ($0.totalPrice ?? 0) < ($1.totalPrice ?? 0) }
        case .storage:
            items.sort { $0.selectedStorage.rawValue < $1.selectedStorage.rawValue }
        }

        return items
    }

    private func secondsUntilNextLocalMidnight(from date: Date = Date()) -> TimeInterval {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        if let nextMidnight = cal.date(byAdding: .day, value: 1, to: startOfDay) {
            return nextMidnight.timeIntervalSince(date)
        }
        return 24 * 60 * 60
    }

    private func scheduleMidnightTick() {
        dailyTimer?.invalidate()
        let delay = secondsUntilNextLocalMidnight()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            timeTick = Date()
            self.dailyTimer?.invalidate()
            self.dailyTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
                timeTick = Date()
            }
            RunLoop.main.add(self.dailyTimer!, forMode: .common)
        }
    }
}

// MARK: - Minimal sticky bar

struct MinimalSelectionBar: View {
    let selectedCount: Int
    let onClear: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(selectedCount) selected")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .foregroundColor(.red.opacity(0.9))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selection")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.red.opacity(0.55))
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
            .accessibilityLabel("Delete selected")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.red.opacity(0.08))
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
    }
}

// MARK: - Item row (context menu matches Home tab)

private struct AllItemRow: View {
    @EnvironmentObject private var store: AppStore
    let item: ReceiptItem

    @State private var showEditQuantity = false
    @State private var editedQuantity: Int = 1

    @State private var showEditDate = false
    @State private var editedDate = Date()

    @State private var showEditItemSheet = false
    @State private var showStoragePicker = false

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack(alignment: .center) {
                        Circle()
                            .fill(storageColor.opacity(0.18))
                            .overlay(Circle().stroke(storageColor, lineWidth: 1))

                        Text(item.iconEmoji)
                            .font(.system(size: 22))

                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: storageIcon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(storageColor)
                            )
                            .offset(x: 12, y: 8)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Text(expiresText)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text("Bought: \(formatDate(item.purchasedAt))")
                            .font(.caption2)
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

                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        GeometryReader { geo in
                            Capsule()
                                .fill(progressColor())
                                .frame(width: max(0, progressFraction()) * geo.size.width)
                        }
                    }
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)

                    if item.isUsed {
                        Label("Used", systemImage: "checkmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(.green.opacity(0.25), lineWidth: 1))
                    } else {
                        Button("Mark used") {
                            store.toggleUsed(item)
                            Haptics.selection()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                .padding(.top, 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contextMenu {
                Button { showEditItemSheet = true } label: { Label("Edit Item", systemImage: "pencil") }
                Button { showStoragePicker = true } label: { Label("Change Storage", systemImage: "tray.and.arrow.down") }
                Button { primeEditedDate(); showEditDate = true } label: { Label("Edit Expiration", systemImage: "calendar.badge.clock") }
                Divider()
                Button(role: .destructive) {
                    store.removeItem(item)
                    Haptics.notify(.warning)
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .glassCardStyle(GlassCardStyle(padding: 6))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showStoragePicker) {
            StoragePickerSheet(
                title: "Storage",
                selected: item.selectedStorage,
                onSelect: { updateStorage($0); showStoragePicker = false }
            )
            .presentationDetents([.medium])
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

    private var storageIcon: String { item.selectedStorage.iconName }

    private var badgeColor: Color {
        switch item.urgency() {
        case .expired: return .red
        case .soon: return .orange
        case .fresh: return .secondary
        }
    }

    private var expiresText: String {
        let d = ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601) ?? .distantFuture
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: d)
        ).day ?? 0

        if days < 0 { return "Expires — expired" }
        if days == 0 { return "Expires — today" }
        if days == 1 { return "Expires — in 1 day" }
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
        if total <= 0 { return 1 }

        let elapsed = Date().timeIntervalSince(start)
        let fraction = elapsed / total

        return CGFloat(min(1, max(0, fraction)))
    }

    private func daysUntilExpiry() -> Int? {
        guard let end = expiryDate() else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfEnd = Calendar.current.startOfDay(for: end)
        return Calendar.current.dateComponents([.day], from: startOfToday, to: startOfEnd).day
    }

    private func progressColor() -> Color {
        let days = daysUntilExpiry() ?? 0
        if days < 0 { return .gray }        // expired
        if days == 0 { return .red }        // expires today
        if days <= 2 { return .red }
        else if days <= 7 { return .yellow }
        else { return .green }
    }
}

// MARK: - Weekly Progress View (UPDATED per your spec)

struct WeeklyProgressView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedWeekLabel: String? = nil

    private let savedDarkGreen = Color(red: 0.0, green: 0.45, blue: 0.2)

    private let isoCal: Calendar = {
        var c = Calendar(identifier: .iso8601) // week starts Monday
        c.timeZone = .current
        return c
    }()

    private func startOfWeekMonday(_ date: Date) -> Date {
        let comps = isoCal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return isoCal.date(from: comps) ?? isoCal.startOfDay(for: date)
    }

    private var thisWeekStart: Date { startOfWeekMonday(Date()) }
    private var thisWeekEnd: Date {
        isoCal.date(byAdding: .day, value: 7, to: thisWeekStart)
        ?? thisWeekStart.addingTimeInterval(7 * 24 * 3600)
    }

    private func weekLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func moneySum(_ items: [ReceiptItem]) -> Double {
        items.reduce(0) { acc, it in
            if let t = it.totalPrice { return acc + t }
            if let ppu = it.pricePerUnit { return acc + ppu * Double(max(1, it.quantity)) }
            return acc
        }
    }

    // ✅ Saved (this week) = items marked used in this week
    private var savedThisWeek: Double {
        let saved = store.items.filter { it in
            guard it.isUsed, let usedAt = it.usedAt else { return false }
            return usedAt >= thisWeekStart && usedAt < thisWeekEnd
        }
        return moneySum(saved)
    }

    // ✅ Pending (this week) = not used, not expired, expiring this week
    private var pendingThisWeek: Double {
        let pending = store.items.filter { it in
            guard !it.isUsed, it.urgency() != .expired else { return false }
            guard let exp = ISO8601Helper.formatter.date(from: it.effectiveExpiryISO8601) else { return false }
            return exp >= thisWeekStart && exp < thisWeekEnd
        }
        return moneySum(pending)
    }

    // ✅ Wasted (this week) = expired this week (and not used)
    private var wastedThisWeek: Double {
        let wasted = store.items.filter { it in
            guard !it.isUsed, it.urgency() == .expired else { return false }
            guard let exp = ISO8601Helper.formatter.date(from: it.effectiveExpiryISO8601) else { return false }
            return exp >= thisWeekStart && exp < thisWeekEnd
        }
        return moneySum(wasted)
    }

    // ✅ Chart should show week-over-week Saved/Wasted only
    private struct BarPoint: Identifiable, Equatable {
        let id = UUID()
        let weekStart: Date
        let kind: String // "Saved" or "Wasted"
        let value: Double
    }

    private var buckets: [AppStore.WeekBucket] {
        store.weeklyBuckets(weeksBack: 8)
    }

    private var barPoints: [BarPoint] {
        buckets.flatMap { b in
            [
                BarPoint(weekStart: b.weekStart, kind: "Saved", value: b.saved),
                BarPoint(weekStart: b.weekStart, kind: "Wasted", value: b.wasted)
            ]
        }
    }

    private static let currencyFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.maximumFractionDigits = 2
        nf.currencySymbol = Locale.current.currencySymbol ?? "$"
        return nf
    }()

    private func formattedCurrency(_ value: Double) -> String {
        WeeklyProgressView.currencyFormatter.string(from: NSNumber(value: value)) ?? ""
    }

    var body: some View {
        List {

            // ✅ Top tiles (same width + same height)
            Section {
                let tileH: CGFloat = 104

                HStack(spacing: 12) {
                    StatTile(
                        mainTitle: "Savings",
                        subtitle: "This week",
                        amount: formattedCurrency(savedThisWeek),
                        color: savedDarkGreen,
                        secondaryLabel: "Pending",
                        secondaryAmount: formattedCurrency(pendingThisWeek),
                        secondaryColor: .green,
                        fixedHeight: tileH
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: tileH)
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    StatTile(
                        mainTitle: "Wasted",
                        subtitle: "This week",
                        amount: formattedCurrency(wastedThisWeek),
                        color: .red,
                        fixedHeight: tileH
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: tileH)
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Weekly Savings vs Waste") {

                // ✅ Simple legend (always visible)
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Capsule().fill(savedDarkGreen).frame(width: 18, height: 6)
                        Text("Saved").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Capsule().fill(Color.red.opacity(0.75)).frame(width: 18, height: 6)
                        Text("Wasted").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 6)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Chart(barPoints) { point in
                    BarMark(
                        x: .value("Week", weekLabel(for: point.weekStart)),
                        y: .value("Amount", point.value)
                    )
                    .position(by: .value("Kind", point.kind))
                    .foregroundStyle(point.kind == "Saved" ? savedDarkGreen : .red.opacity(0.75))
                    .cornerRadius(3)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 8)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(centered: true)
                    }
                }
                .chartXSelection(value: $selectedWeekLabel)
                .chartYAxisLabel(position: .leading) {
                    Text("Amount")
                        .rotationEffect(.degrees(180))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .chartXAxisLabel("Week", position: .bottom, alignment: .center)
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Optional selection detail (kept simple)
                if let selected = selectedWeekLabel,
                   let b = buckets.first(where: { weekLabel(for: $0.weekStart) == selected }) {

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Week of \(selected)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 14) {
                                HStack(spacing: 8) {
                                    Circle().fill(savedDarkGreen).frame(width: 7, height: 7)
                                    Text("Saved")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(formattedCurrency(b.saved))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(savedDarkGreen)
                                }

                                HStack(spacing: 8) {
                                    Circle().fill(Color.red.opacity(0.85)).frame(width: 7, height: 7)
                                    Text("Wasted")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(formattedCurrency(b.wasted))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.red)
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selectedWeekLabel)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Weekly Progress")
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sf_appearance") private var appearanceRaw: Int = 0

    var body: some View {
        NavigationStack {
            List {
                Picker("Appearance", selection: $appearanceRaw) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Storage Picker Sheet (inline replacement)

struct StoragePickerSheet: View {
    let title: String
    let selected: StorageMode
    let onSelect: (StorageMode) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(StorageMode.allCases, id: \.self) { mode in
                        Button {
                            onSelect(mode)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.iconName)
                                    .foregroundStyle(color(for: mode))
                                Text(label(for: mode))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if mode == selected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func label(for mode: StorageMode) -> String {
        switch mode {
        case .pantry: return "Pantry"
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        }
    }

    private func color(for mode: StorageMode) -> Color {
        switch mode {
        case .pantry: return .brown
        case .fridge: return .blue
        case .freezer: return .indigo
        }
    }
}

