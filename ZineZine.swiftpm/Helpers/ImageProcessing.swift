//
//  ImageProcessing.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import CoreImage
import UIKit
import Vision

/// Errors from background removal.
enum ImageProcessingError: LocalizedError {
    case noSubject
    case failed

    var errorDescription: String? {
        switch self {
        case .noSubject: return "Nenhum objeto encontrado na imagem."
        case .failed: return "Não foi possível processar a imagem."
        }
    }
}

/// Layer filters, background removal and freehand cutouts.
enum ImageProcessing {
    /// Shared Core Image context. `CIContext` is thread-safe.
    nonisolated(unsafe) private static let context = CIContext()

    // MARK: - Filters

    /// Returns a filtered copy of the image. Transparent areas stay transparent.
    static func apply(_ filter: LayerFilter, to image: UIImage) -> UIImage {
        guard filter != .none, let cgImage = image.cgImage else { return image }
        let input = CIImage(cgImage: cgImage)
        // Dot sizes follow the image width, so thumbnails and exports look alike.
        let pixelWidth = input.extent.width
        let output: CIImage

        switch filter {
        case .none:
            return image
        case .xerox:
            output = input
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 1.9,
                    kCIInputBrightnessKey: 0.05
                ])
                .applyingFilter("CIDotScreen", parameters: [
                    kCIInputCenterKey: CIVector(x: 0, y: 0),
                    kCIInputWidthKey: max(2, pixelWidth / 220),
                    kCIInputSharpnessKey: 0.75,
                    kCIInputAngleKey: 0.2
                ])
        case .halftone:
            output = input.applyingFilter("CICMYKHalftone", parameters: [
                kCIInputCenterKey: CIVector(x: 0, y: 0),
                kCIInputWidthKey: max(3, pixelWidth / 120),
                kCIInputSharpnessKey: 0.8,
                kCIInputAngleKey: 0.3
            ])
        case .noir:
            output = input.applyingFilter("CIPhotoEffectNoir")
        case .cyanotype:
            output = input.applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0, green: 0.2, blue: 0.5),
                kCIInputIntensityKey: 0.97
            ])
        case .redBlue:
            output = input.applyingFilter("CIFalseColor", parameters: [
                "inputColor0": CIColor(red: 0, green: 0.05, blue: 0.4),
                "inputColor1": CIColor(red: 0.8, green: 0, blue: 0)
            ])
        case .negative:
            output = input.applyingFilter("CIColorInvert")
        }

        let masked = output
            .cropped(to: input.extent)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: input])
        guard let result = context.createCGImage(masked, from: input.extent) else { return image }
        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    // MARK: - Background removal

    /// Keeps only the main subject of the image. Runs off the main thread.
    static func removingBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ImageProcessingError.failed }
        let input = CGImageBox(image: cgImage)
        let output = try await Task.detached(priority: .userInitiated) {
            try Self.subject(of: input)
        }.value
        return UIImage(cgImage: output.image, scale: image.scale, orientation: .up)
    }

    private static func subject(of input: CGImageBox) throws -> CGImageBox {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: input.image)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw ImageProcessingError.noSubject
        }
        let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                         from: handler,
                                                         croppedToInstancesExtent: false)
        let masked = CIImage(cvPixelBuffer: buffer)
        guard let result = context.createCGImage(masked, from: masked.extent) else {
            throw ImageProcessingError.failed
        }
        return CGImageBox(image: result)
    }

    // MARK: - Cutout

    /// Keeps the part of the image inside a closed path.
    ///
    /// - Parameters:
    ///   - image: Source image.
    ///   - points: Path in image points. Needs at least 3 points.
    /// - Returns: Image with the same size and transparent outside the path.
    static func cutOut(_ image: UIImage, along points: [CGPoint]) -> UIImage? {
        guard points.count > 2 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            let path = UIBezierPath()
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            path.close()
            path.addClip()
            image.draw(at: .zero)
        }
    }
}

/// Passes a `CGImage` to and from a background task.
private struct CGImageBox: @unchecked Sendable {
    let image: CGImage
}
