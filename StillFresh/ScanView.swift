import SwiftUI
import VisionKit

struct ScanView: View {
    @EnvironmentObject private var store: AppStore

    @State private var isPresentingScanner = false
    @State private var scannedImages: [UIImage] = [] // in-memory only (MVP)
    @State private var isProcessing = false
    @State private var stage: ProcessingStage = .capturing
    @State private var progress: Double = 0
    @State private var hint: String = "Point at the receipt"
    
    @State private var pendingItems: [ReceiptItem] = []
    @State private var showPendingPreview = false

    @State private var showAddedSuccess: Bool = false

    @State private var replaceIndex: Int? = nil
    @State private var previewIndex: Int? = nil

    @State private var editingIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScanHeaderCard(
                        scannedImagesIsEmpty: scannedImages.isEmpty,
                        onStartScan: { isPresentingScanner = true },
                        onClearScans: { scannedImages.removeAll() }
                    )

                    if !scannedImages.isEmpty {
                        ScansSection(
                            scannedImages: scannedImages,
                            onProcess: { Task { await processScans() } },
                            onOpenPreview: { idx in
                                previewIndex = idx
                            },
                            onReplaceScan: { idx in
                                replaceIndex = idx
                            },
                            onEditScan: { idx in
                                editingIndex = idx
                            },
                            onDeleteScan: { idx in
                                if scannedImages.indices.contains(idx) {
                                    scannedImages.remove(at: idx)
                                }
                            }
                        )
                    } else {
                        TipCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $isPresentingScanner) {
            DocumentScannerView { images in
                scannedImages.append(contentsOf: images)
            }
        }
        .sheet(isPresented: Binding(
            get: { replaceIndex != nil },
            set: { newValue in if !newValue { replaceIndex = nil } }
        )) {
            DocumentScannerView { images in
                if let idx = replaceIndex, let first = images.first {
                    scannedImages[idx] = first
                    if images.count > 1 {
                        scannedImages.append(contentsOf: images.dropFirst())
                    }
                }
                replaceIndex = nil
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { previewIndex != nil },
            set: { newValue in if !newValue { previewIndex = nil } }
        )) {
            if let idx = previewIndex, scannedImages.indices.contains(idx) {
                ScanPreviewView(
                    image: scannedImages[idx],
                    onClose: { previewIndex = nil },
                    onReplace: {
                        replaceIndex = idx
                        previewIndex = nil
                    },
                    onDelete: {
                        scannedImages.remove(at: idx)
                        previewIndex = nil
                    }
                )
            }
        }
.fullScreenCover(isPresented: Binding(
            get: { editingIndex != nil },
            set: { newValue in if !newValue { editingIndex = nil } }
        )) {
            if let idx = editingIndex, scannedImages.indices.contains(idx) {
                ImageEditorView(
                    original: scannedImages[idx],
                    onCancel: { editingIndex = nil },
                    onSave: { updated in
                        scannedImages[idx] = updated
                        editingIndex = nil
                    }
                )
            }
        }
        .processingOverlay(isProcessing: isProcessing, stage: stage, progress: progress, hint: hint)
        .pendingPreviewOverlay(
            show: showPendingPreview,
            isProcessing: isProcessing,
            items: pendingItems,
            onCancel: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showPendingPreview = false
                    pendingItems.removeAll()
                }
            },
            onConfirmSelected: { selected in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if !selected.isEmpty {
                        store.items.append(contentsOf: selected)
                        Haptics.notify(.success)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showAddedSuccess = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showAddedSuccess = false
                            }
                        }
                    }
                    showPendingPreview = false
                    pendingItems.removeAll()
                }
            }
        )
        .addedSuccessOverlay(show: showAddedSuccess)

    }

    private func processScans() async {
        guard !scannedImages.isEmpty else { return }
        await MainActor.run { isProcessing = true }

        do {
            await MainActor.run {
                stage = .enhancing
                hint = "Cleaning up text for fast understanding"
                progress = 0.1
            }

            // ✅ Returns [Data] in your project
            let processedChunks: [Data] = try await ImagePreprocessor.preprocess(images: scannedImages) { p in
                await MainActor.run { progress = 0.1 + 0.45 * p }
            }

            await MainActor.run {
                stage = .understanding
                hint = "Extracting items and expiry estimates"
                progress = 0.65
            }
            
            print("processedChunks:", processedChunks.map { $0.count })

            // MVP: pick the largest chunk (most detail)
            guard let best = processedChunks.max(by: { $0.count < $1.count }) else {
                throw NSError(domain: "ScanView", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "No processed image data"])
            }
            
            print("best bytes:", best.count)

            let dataURL = jpegDataURL(from: best)

            let response = try await APIClient.shared.classifyReceipt(
                imageDataURL: dataURL,
                timezone: "America/Los_Angeles",
                partialScan: processedChunks.count > 1
            )

            await MainActor.run {
                stage = .organizing
                hint = "Organizing items"
                progress = 0.92
            }

            let mapped = response.items.map { $0.toReceiptItem() }

            await MainActor.run {
                pendingItems = mapped
                showPendingPreview = true
                scannedImages.removeAll()
                progress = 1.0
                // Stop the full-screen processing overlay once we have items to review.
                isProcessing = false
            }
        } catch {
            let message = String(describing: error)
            print("❌ processScans failed:", message)

            await MainActor.run {
                store.snackbar = SnackbarState(
                    message: message,
                    actionTitle: "OK",
                    action: {}
                )
            }
        }

        await MainActor.run { isProcessing = false }
    }

    private func jpegDataURL(from data: Data) -> String {
        "data:image/jpeg;base64," + data.base64EncodedString()
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onComplete: ([UIImage]) -> Void
        init(onComplete: @escaping ([UIImage]) -> Void) { self.onComplete = onComplete }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) {
                self.onComplete(images)
            }
        }
    }
}
private extension View {
    func processingOverlay(isProcessing: Bool, stage: ProcessingStage, progress: Double, hint: String) -> some View {
        overlay {
            if isProcessing {
                ProcessingOverlay(stage: stage, progress: progress, hint: hint)
                    .ignoresSafeArea()
                    .zIndex(1000)
            }
        }
    }

    func pendingPreviewOverlay(
        show: Bool,
        isProcessing: Bool,
        items: [ReceiptItem],
        onCancel: @escaping () -> Void,
        onConfirmSelected: @escaping ([ReceiptItem]) -> Void
    ) -> some View {
        overlay {
            if show {
                FloatingPendingItemsView(
                    items: items,
                    onCancel: onCancel,
                    onConfirmSelected: onConfirmSelected,
                    isProcessingExternal: isProcessing
                )
                .ignoresSafeArea()
                .zIndex(1001)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    func addedSuccessOverlay(show: Bool) -> some View {
        overlay {
            if show {
                AddedSuccessOverlay()
                    .ignoresSafeArea()
                    .zIndex(1100)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }

}

private struct ScanHeaderCard: View {
    let scannedImagesIsEmpty: Bool
    let onStartScan: () -> Void
    let onClearScans: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Scan your receipt")
                    .font(.headline)
                Text("You can scan multiple parts. We’ll merge them into one session.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button(action: onStartScan) {
                        Label(scannedImagesIsEmpty ? "Start scanning" : "Add another scan", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(height: 56)

                    if !scannedImagesIsEmpty {
                        Button(action: onClearScans) {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

private struct ScansSection: View {
    let scannedImages: [UIImage]
    let onProcess: () -> Void
    let onOpenPreview: (Int) -> Void
    let onReplaceScan: (Int) -> Void
    let onEditScan: (Int) -> Void
    let onDeleteScan: (Int) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Scans")
                    .font(.headline)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(scannedImages.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 160)
                                    .clipped()
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                                    )
                                    .accessibilityLabel("Scan \(idx+1)")
                                    .onTapGesture { onOpenPreview(idx) }

                                // Top-right delete (X)
                                Button {
                                    onDeleteScan(idx)
                                    Haptics.selection()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.white.opacity(0.92))
                                        .shadow(radius: 6, y: 2)
                                        .padding(8)
                                }
                                .buttonStyle(.plain)

                                // Bottom-right magnify/edit
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button {
                                            onEditScan(idx)
                                            Haptics.selection()
                                        } label: {
                                            Image(systemName: "magnifyingglass.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(.white.opacity(0.92))
                                                .shadow(radius: 6, y: 2)
                                                .padding(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(width: 120, height: 160)
                            .contextMenu {
                                Button("Edit", systemImage: "magnifyingglass") { onEditScan(idx) }
                                Button("Replace scan", systemImage: "camera") { onReplaceScan(idx) }
                                Button("Delete", systemImage: "trash", role: .destructive) { onDeleteScan(idx) }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                Button(action: onProcess) {
                    Label("Process with AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct TipCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tip")
                    .font(.headline)
                Text("Fill the frame. Avoid harsh glare. If the receipt is long, scan it in overlapping chunks.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ScanPreviewView: View {
    let image: UIImage
    let onClose: () -> Void
    let onReplace: () -> Void
    let onDelete: () -> Void
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onClose)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: onReplace) {
                        Label("Replace", systemImage: "camera")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
        }
    }
}



private struct AddedSuccessOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.10).ignoresSafeArea()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 92, height: 92)
                        .overlay(
                            Circle().stroke(Color.green.opacity(0.35), lineWidth: 1)
                        )

                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Color.green)
                }

                Text("Added")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
            .shadow(radius: 18, y: 10)
        }
    }
}
