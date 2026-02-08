import SwiftUI

/// Shared sheet used across Home / All Items / Scan review to edit an item.
struct EditReceiptItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    let original: ReceiptItem
    let onSave: (ReceiptItem) -> Void

    @State private var name: String
    @State private var quantity: Int
    @State private var storage: StorageMode
    @State private var expiryDate: Date

    init(item: ReceiptItem, onSave: @escaping (ReceiptItem) -> Void) {
        self.original = item
        self.onSave = onSave

        _name = State(initialValue: item.name)
        _quantity = State(initialValue: max(1, item.quantity))
        _storage = State(initialValue: item.selectedStorage)

        let current = ISO8601Helper.formatter.date(from: item.effectiveExpiryISO8601) ?? Date()
        _expiryDate = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)

                    Stepper(value: $quantity, in: 1...99) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(quantity)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Storage") {
                    Picker("Storage", selection: $storage) {
                        Text("Pantry").tag(StorageMode.pantry)
                        Text("Refrigerator").tag(StorageMode.fridge)
                        Text("Freezer").tag(StorageMode.freezer)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Expiration") {
                    DatePicker("Expires on", selection: $expiryDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)

                    Text("Saving sets an override for this purchase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var updated = original
                        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.quantity = max(1, quantity)
                        updated.selectedStorage = storage
                        updated.userOverrideExpiryISO8601 = ISO8601Helper.formatter.string(from: expiryDate)
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
