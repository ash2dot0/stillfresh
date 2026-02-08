import SwiftUI

struct FloatingPendingItemsView: View {
    let items: [ReceiptItem]
    let onCancel: () -> Void
    let onConfirmSelected: ([ReceiptItem]) -> Void
    let isProcessingExternal: Bool?

    @State private var selectedIDs: Set<ReceiptItem.ID> = []
    @State private var draftItems: [ReceiptItem] = []

    @State private var purchaseDate: Date = Date()
    @State private var showPurchaseDatePicker = false

    @State private var editingItemID: ReceiptItem.ID?
    @State private var showEditSheet = false

    private var isProcessing: Bool { isProcessingExternal ?? items.isEmpty }

    private var dimBackground: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea(edges: [.top, .horizontal])
            .transition(.opacity)
    }

    @ViewBuilder
    private var headerDescription: some View {
        if isProcessing && items.isEmpty {
            Text("Working on it…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        } else {
            let count = draftItems.count
            let suffix = count == 1 ? "" : "s"
            Text("We found \(count) item\(suffix). Tap an item to edit before adding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var processingHeader: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.1)

            VStack(spacing: 4) {
                Text("Processing…")
                    .font(.headline)
                Text("Extracting items and estimating expiries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
            Button("Cancel") { onCancel() }
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }

    private var purchaseDateRow: some View {
        Button {
            showPurchaseDatePicker = true
            Haptics.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Purchase date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDate(purchaseDate))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPurchaseDatePicker) {
            NavigationStack {
                VStack(spacing: 18) {
                    DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                    Text("If you bought these earlier, expiration will be closer.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .navigationTitle("Purchase date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Close") { showPurchaseDatePicker = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") {
                            applyPurchaseDate(purchaseDate)
                            showPurchaseDatePicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func itemRow(_ item: ReceiptItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return GlassCard {
            HStack(spacing: 12) {
                Button { toggle(item.id) } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Text(item.iconEmoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("×\(item.quantity)")
                        Text("•")
                        Text(item.selectedStorage.label)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Expires: \(formatDateTime(expiryDate(for: item)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            // tap toggles selection
            toggle(item.id)
        }
        .onLongPressGesture {
            // long press opens edit
            editingItemID = item.id
            showEditSheet = true
            Haptics.selection()
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                // double tap also edits
                editingItemID = item.id
                showEditSheet = true
                Haptics.selection()
            }
        )
    }

    var body: some View {
        ZStack {
            dimBackground
                .onTapGesture { onCancel() }

            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                Text(isProcessing ? "Processing" : "Review items")
                    .font(.headline)

                headerDescription

                if !isProcessing {
                    purchaseDateRow

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(draftItems) { item in
                                itemRow(item)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 440)

                    HStack(spacing: 10) {
                        Button("Cancel") { onCancel() }
                            .buttonStyle(.bordered)

                        Button {
                            let selected: [ReceiptItem] = draftItems.filter { selectedIDs.contains($0.id) }
                            onConfirmSelected(selected)
                        } label: {
                            Label("Add \(selectedIDs.count)", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedIDs.isEmpty)
                    }
                    .padding(.bottom, 8)
                } else {
                    processingHeader
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            .shadow(radius: 16, y: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: draftItems.count)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 72) }
        }
        .onAppear {
            syncFromIncoming(items)
        }
        .onChange(of: items) { _, newItems in
            syncFromIncoming(newItems)
        }
        .sheet(isPresented: $showEditSheet) {
            if let id = editingItemID,
               let idx = draftItems.firstIndex(where: { $0.id == id }) {
                PendingItemEditSheet(
                    item: draftItems[idx],
                    onSave: { updated in
                        draftItems[idx] = updated
                        Haptics.notify(.success)
                    }
                )
                .presentationDetents([.medium, .large])
            } else {
                Text("No item selected")
                    .presentationDetents([.height(160)])
            }
        }
    }

    private func syncFromIncoming(_ incoming: [ReceiptItem]) {
        // Keep draft in sync, but don't blow away edits if the same ids exist.
        if draftItems.isEmpty || incoming.map(\.id) != draftItems.map(\.id) {
            draftItems = incoming
        }
        if let first = draftItems.first {
            purchaseDate = first.purchasedAt
        } else {
            purchaseDate = Date()
        }
        selectedIDs = Set(draftItems.map { $0.id })
    }

    private func toggle(_ id: ReceiptItem.ID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func applyPurchaseDate(_ newDate: Date) {
        guard !draftItems.isEmpty else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            for i in draftItems.indices {
                let old = draftItems[i].purchasedAt
                let delta = newDate.timeIntervalSince(old)
                draftItems[i].purchasedAt = newDate

                draftItems[i].expiryByStorageISO8601 = shiftExpiryMap(draftItems[i].expiryByStorageISO8601, delta: delta)

                if let override = draftItems[i].userOverrideExpiryISO8601,
                   let shifted = shiftISO8601(override, delta: delta) {
                    draftItems[i].userOverrideExpiryISO8601 = shifted
                }
            }
        }
        Haptics.selection()
    }

    private func shiftExpiryMap(_ map: [StorageMode: String], delta: TimeInterval) -> [StorageMode: String] {
        var out = map
        for k in map.keys {
            if let iso = map[k], let shifted = shiftISO8601(iso, delta: delta) {
                out[k] = shifted
            }
        }
        return out
    }

    private func shiftISO8601(_ iso: String, delta: TimeInterval) -> String? {
        guard let d = ISO8601Helper.formatter.date(from: iso) else { return nil }
        return ISO8601Helper.formatter.string(from: d.addingTimeInterval(delta))
    }

    private func expiryDate(for item: ReceiptItem) -> Date? {
        ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601)
    }

    private func formatDate(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: d)
    }

    private func formatDateTime(_ d: Date?) -> String {
        guard let d else { return "Unknown" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: d)
    }
}

private struct PendingItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ReceiptItem
    let onSave: (ReceiptItem) -> Void

    @State private var expiryOverrideDate: Date
    @State private var hasOverride: Bool

    init(item: ReceiptItem, onSave: @escaping (ReceiptItem) -> Void) {
        _item = State(initialValue: item)
        self.onSave = onSave

        let current = ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601) ?? Date().addingTimeInterval(24*3600)
        _expiryOverrideDate = State(initialValue: current)
        _hasOverride = State(initialValue: item.userOverrideExpiryISO8601 != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $item.name)
                        .textInputAutocapitalization(.words)

                    Stepper(value: $item.quantity, in: 1...99) {
                        Text("Quantity: \(item.quantity)")
                    }

                    if let amt = item.perUnitAmount, let u = item.perUnitUnit {
                        Text("Per unit: \(prettyAmount(amt)) \(u)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Storage") {
                    StorageSegmentedPicker(selected: $item.selectedStorage)
                }

                Section("Expiration") {
                    Toggle("Override expiration", isOn: $hasOverride)

					DatePicker("Expires", selection: $expiryOverrideDate, displayedComponents: [.date])
                        .disabled(!hasOverride)
                }
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if hasOverride {
                            item.userOverrideExpiryISO8601 = ISO8601Helper.formatter.string(from: expiryOverrideDate)
                        } else {
                            item.userOverrideExpiryISO8601 = nil
                        }
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func prettyAmount(_ v: Double) -> String {
        v == floor(v) ? String(Int(v)) : String(v)
    }
}

private struct StorageSegmentedPicker: View {
    @Binding var selected: StorageMode

    var body: some View {
        HStack(spacing: 12) {
            option(.pantry)
            option(.fridge)
            option(.freezer)
        }
        .padding(.vertical, 4)
    }

    private func option(_ mode: StorageMode) -> some View {
        Button {
            selected = mode
            Haptics.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 14, weight: .bold))
                Text(mode.label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
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

