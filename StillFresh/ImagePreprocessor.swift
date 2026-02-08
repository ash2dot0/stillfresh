import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImagePreprocessor {
    /// Preprocesses images for AI:
    /// - de-skew / perspective correct (fallback if scanner didn't do it)
    /// - crop to bounds
    /// - contrast + mild sharpening
    /// - reduce highlights/glare a bit
    /// - resize + compress
    static func preprocess(images: [UIImage], progress: @escaping @Sendable (Double) async -> Void) async throws -> [Data] {
        let ciContext = CIContext(options: [.cacheIntermediates: true])
        var out: [Data] = []
        out.reserveCapacity(images.count)

        for (idx, image) in images.enumerated() {
            let stepStart = Double(idx) / Double(max(1, images.count))
            await progress(stepStart)

            guard let ci = CIImage(image: image) else { continue }

            // 1) Try rectangle detection to get better crop/perspective if needed.
            let corrected = try await perspectiveCorrectIfNeeded(ciImage: ci)

            // 2) Enhance readability.
            let enhanced = enhance(ciImage: corrected)

            // 3) Resize + compress intelligently.
            let data = try compress(ciImage: enhanced, context: ciContext)
            out.append(data)

            await progress(Double(idx + 1) / Double(max(1, images.count)))
        }

        return out
    }

    private static func enhance(ciImage: CIImage) -> CIImage {
        let gray = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.25,
            kCIInputBrightnessKey: 0.02
        ])

        let highlights = CIFilter.highlightShadowAdjust()
        highlights.inputImage = gray
        highlights.highlightAmount = 0.85 // reduce bright glare a bit
        highlights.shadowAmount = 0.15

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = highlights.outputImage ?? gray
        sharpen.sharpness = 0.45

        let noise = CIFilter.noiseReduction()
        noise.inputImage = sharpen.outputImage ?? gray
        noise.noiseLevel = 0.02
        noise.sharpness = 0.4

        return noise.outputImage ?? (sharpen.outputImage ?? gray)
    }

    private static func compress(ciImage: CIImage, context: CIContext) throws -> Data {
        // Target: keep text legible while minimizing upload. Receipts are mostly monochrome.
        // Heuristic: max dimension 1600px.
        let maxDim: CGFloat = 1600
        let extent = ciImage.extent.integral
        let scale = min(1.0, maxDim / max(extent.width, extent.height))
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(resized, from: resized.extent) else {
            throw NSError(domain: "ImagePreprocessor", code: -1)
        }

        let ui = UIImage(cgImage: cgImage)
        // JPEG quality: receipts compress well. Adjust if you see OCR/AI failures.
        guard let data = ui.jpegData(compressionQuality: 0.72) else {
            throw NSError(domain: "ImagePreprocessor", code: -2)
        }
        return data
    }

    private static func perspectiveCorrectIfNeeded(ciImage: CIImage) async throws -> CIImage {
        // VNDocumentCameraViewController already gives perspective-corrected pages.
        // This is a fallback when using other capture sources later.
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 45.0

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard
            let obs = request.results?.first as? VNRectangleObservation
        else { return ciImage }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = obs.topLeft.applying(to: ciImage.extent)
        filter.topRight = obs.topRight.applying(to: ciImage.extent)
        filter.bottomLeft = obs.bottomLeft.applying(to: ciImage.extent)
        filter.bottomRight = obs.bottomRight.applying(to: ciImage.extent)

        return filter.outputImage ?? ciImage
    }
}

private extension CGPoint {
    func applying(to extent: CGRect) -> CGPoint {
        // VNRectangleObservation uses normalized coordinates with origin at lower-left.
        CGPoint(x: extent.origin.x + x * extent.size.width,
                y: extent.origin.y + y * extent.size.height)
    }
}
