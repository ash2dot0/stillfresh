import SwiftUI
import UIKit

/// Lightweight in-app editor for a scanned receipt image.
/// Supports pinch-to-zoom + pan (crop-by-framing) and optional rotation.
/// "Save" returns a new UIImage snapshot of the visible crop area.
struct ImageEditorView: View {
    let original: UIImage
    let onCancel: () -> Void
    let onSave: (UIImage) -> Void

    @State private var working: UIImage
    @State private var rotationTurns: Int = 0
    @State private var exportRequestID: UUID = UUID()

    init(original: UIImage, onCancel: @escaping () -> Void, onSave: @escaping (UIImage) -> Void) {
        self.original = original
        self.onCancel = onCancel
        self.onSave = onSave
        _working = State(initialValue: original)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ZoomableImageCropView(image: $working, exportRequestID: $exportRequestID) { exported in
                    // Export callback: treat as "Save"
                    onSave(exported)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .navigationTitle("Edit scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        rotateRight()
                        Haptics.selection()
                    } label: {
                        Image(systemName: "rotate.right")
                    }
                    .accessibilityLabel("Rotate")

                    Button {
                        // Trigger an export of the current crop.
                        exportRequestID = UUID()
                        Haptics.selection()
                    } label: {
                        Text("Save").fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func rotateRight() {
        rotationTurns = (rotationTurns + 1) % 4
        if let rotated = working.rotated90Degrees(clockwise: true) {
            working = rotated
        }
    }
}

/// A zoomable/pannable cropper backed by UIScrollView.
/// Export returns a snapshot of the visible content (cropped to the viewport).
private struct ZoomableImageCropView: UIViewRepresentable {
    @Binding var image: UIImage
    @Binding var exportRequestID: UUID
    var onExport: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onExport: onExport) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.backgroundColor = .clear
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.bouncesZoom = true
        scroll.minimumZoomScale = 1.0
        scroll.maximumZoomScale = 6.0
        scroll.decelerationRate = .fast
        scroll.clipsToBounds = true
        scroll.layer.cornerRadius = 22
        scroll.layer.masksToBounds = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        scroll.addSubview(imageView)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scroll
        scroll.delegate = context.coordinator

        // Add a subtle border
        scroll.layer.borderWidth = 1
        scroll.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }

        // Update image
        if imageView.image !== image {
            imageView.image = image
        }

        // Layout to fill the scroll view (aspect fit within bounds)
        let bounds = scroll.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let size = image.size
        let scale = min(bounds.width / max(size.width, 1), bounds.height / max(size.height, 1))
        let fitSize = CGSize(width: size.width * scale, height: size.height * scale)

        imageView.frame = CGRect(
            x: max(0, (bounds.width - fitSize.width) / 2),
            y: max(0, (bounds.height - fitSize.height) / 2),
            width: fitSize.width,
            height: fitSize.height
        )

        scroll.contentSize = imageView.frame.size

        // Keep content centered when smaller than bounds
        let insetX = max(0, (bounds.width - imageView.frame.width) / 2)
        let insetY = max(0, (bounds.height - imageView.frame.height) / 2)
        scroll.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)

        // Export if requested
        if context.coordinator.lastExportRequestID != exportRequestID {
            context.coordinator.lastExportRequestID = exportRequestID
            DispatchQueue.main.async {
                if let exported = context.coordinator.exportVisibleCrop() {
                    self.onExport(exported)
                }
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onExport: (UIImage) -> Void
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        var lastExportRequestID: UUID = UUID()

        init(onExport: @escaping (UIImage) -> Void) {
            self.onExport = onExport
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center content while zooming
            guard let imageView else { return }
            let bounds = scrollView.bounds

            let insetX = max(0, (bounds.width - imageView.frame.width) / 2)
            let insetY = max(0, (bounds.height - imageView.frame.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        func exportVisibleCrop() -> UIImage? {
            guard let scrollView, let imageView else { return nil }

            // Render the visible viewport of the scroll view.
            let renderer = UIGraphicsImageRenderer(bounds: scrollView.bounds)
            return renderer.image { ctx in
                // Translate so that the content offset is accounted for.
                ctx.cgContext.translateBy(x: -scrollView.contentOffset.x + scrollView.contentInset.left,
                                         y: -scrollView.contentOffset.y + scrollView.contentInset.top)
                imageView.layer.render(in: ctx.cgContext)
            }
        }
    }
}

private extension UIImage {
    func rotated90Degrees(clockwise: Bool) -> UIImage? {
        let radians: CGFloat = clockwise ? .pi / 2 : -.pi / 2
        var newSize = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians)).integral.size
        newSize.width = max(newSize.width, 1)
        newSize.height = max(newSize.height, 1)

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        defer { UIGraphicsEndImageContext() }

        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: radians)
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
