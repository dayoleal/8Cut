//
//  PageRenderer.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import PencilKit

/// Renders pages to images. Used for thumbnails, the reader, sharing and the editor.
@MainActor
enum PageRenderer {
    /// Renders a page.
    ///
    /// - Parameters:
    ///   - page: The page to render.
    ///   - document: Source of drawings and images.
    ///   - scale: Pixels per page point. `1` gives 1000 px wide.
    ///   - includePaper: Fills the paper color first.
    ///   - layerRange: Layers to draw. `nil` draws all.
    /// - Returns: The flattened image.
    static func render(page: ZinePage,
                       in document: ZineDocument,
                       scale: CGFloat,
                       includePaper: Bool = true,
                       layerRange: Range<Int>? = nil) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = includePaper
        let pageRect = ZineFormat.pageRect
        let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)

        return renderer.image { context in
            let cgContext = context.cgContext
            if includePaper {
                page.paperColor.uiColor.setFill()
                cgContext.fill(pageRect)
            }
            cgContext.clip(to: pageRect)

            let range = layerRange ?? page.layers.indices
            for index in range where page.layers.indices.contains(index) {
                let layer = page.layers[index]
                guard layer.isVisible, layer.opacity > 0 else { continue }
                draw(layer, in: document, context: cgContext, scale: scale)
            }
        }
    }

    /// Renders strokes in light mode.
    static func drawingImage(_ drawing: PKDrawing, rect: CGRect, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }

    // MARK: - Private

    private static func draw(_ layer: ZineLayer, in document: ZineDocument, context: CGContext, scale: CGFloat) {
        let alpha = CGFloat(layer.opacity)
        let blend = layer.blendMode.cgBlendMode

        switch layer.content {
        case .drawing:
            let drawing = document.drawing(for: layer.id)
            guard !drawing.strokes.isEmpty else { return }
            let image = drawingImage(drawing, rect: ZineFormat.pageRect, scale: scale)
            image.draw(in: ZineFormat.pageRect, blendMode: blend, alpha: alpha)

        case .image(let content):
            guard let image = document.image(named: content.assetName) else { return }
            context.saveGState()
            let transform = content.transform
            context.translateBy(x: transform.centerX, y: transform.centerY)
            context.rotate(by: transform.rotation)
            context.scaleBy(x: transform.scale, y: transform.scale)
            let rect = CGRect(x: -content.width / 2, y: -content.height / 2,
                              width: content.width, height: content.height)
            image.draw(in: rect, blendMode: blend, alpha: alpha)
            context.restoreGState()
        }
    }
}
