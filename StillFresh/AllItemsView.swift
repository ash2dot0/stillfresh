import SwiftUI

struct AllItemsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var editMode: EditMode = .inactive
    @State private var showSettings = false
    @State private var selection = Set<ReceiptItem.ID>()
    @State private var searchText: String = ""

    enum SortOption: String, CaseIterable, Identifiable {
        case purchaseDate = "Purchase date"
        case name = "Name"
        case expiry = "Expiry"
        case price = "Price"
        case storage = "Storage"
        var id: String { rawValue }
    }
    @State private var sort: SortOption = .expiry

    // 0 = System, 1 = Light, 2 = Dark
    @AppStorage("sf_appearance") private var appearanceRaw: Int = 0
    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        NavigationStack {
            List(selection: isEditing ? $selection : .constant([])) {
                ForEach(displayedItems, id: \.id) { item in
                    row(for: item)
                        .tag(item.id)
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("All Items")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .searchable(text: $searchText)
            .environment(\.editMode, $editMode)

            // ✅ Sticky bottom bar that pushes scroll content above it
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
        }
        .preferredColorScheme(preferredScheme)
        .onAppear { selection.removeAll() }
        .onChange(of: editMode) { _, newMode in
            if !newMode.isEditing { selection.removeAll() }
        }
        .onChange(of: store.items) { _, _ in
            let currentIDs = Set(store.items.map(\.id))
            selection = selection.intersection(currentIDs)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isEditing)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selection.count)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
        }

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

    // MARK: - Rows

    @ViewBuilder
    private func row(for item: ReceiptItem) -> some View {
        if isEditing {
            // editing: no navigation, keep selection clean
            AllItemRow(item: item)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            NavigationLink {
                ItemDetailView(item: item)
            } label: {
                AllItemRow(item: item)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.removeItem(item) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Actions

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

    // MARK: - Data

    private var displayedItems: [ReceiptItem] {
        var items = store.items

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
}

//
// MARK: - Minimal sticky bar (bottom, iOS-y)
//

private struct MinimalSelectionBar: View {
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

//
// MARK: - Row (now matches HomeView ItemRow visuals + quantity + mark used)
//

private struct AllItemRow: View {
    @EnvironmentObject private var store: AppStore
    let item: ReceiptItem

    @State private var showEditQuantity = false
    @State private var editedQuantity: Int = 1

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
                        Text(item.displayName + (item.quantity > 1 ? " ×\(item.quantity)" : ""))
                            .font(.headline)
                            .lineLimit(1)

                        Text(expiresText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Bought: \(formatDate(item.purchasedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // ✅ Quantity button (same as HomeView behavior)
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

                // ✅ Mark used (same as HomeView behavior)
                HStack {
                    Spacer()
                    Button("Mark used") {
                        store.removeItem(item)
                        Haptics.selection()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private func expiryDate() -> Date? {
        ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601)
    }

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

    private func saveQuantity() {
        guard let idx = store.items.firstIndex(of: item) else { return }
        store.items[idx].quantity = max(1, editedQuantity)
        Haptics.notify(.success)
    }
}

//
// MARK: - Settings
//

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

