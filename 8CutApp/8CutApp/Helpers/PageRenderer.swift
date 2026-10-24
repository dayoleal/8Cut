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
    /// - Returns: The flattened image. The page filter is applied only when the
    ///   whole page is rendered with its paper.
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

        let image = renderer.image { context in
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

        guard includePaper, layerRange == nil, page.filter != .none else { return image }
        return ImageProcessing.apply(page.filter, to: image)
    }

    /// Renders strokes in light mode.
    static func drawingImage(_ drawing: PKDrawing, rect: CGRect, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }

    // MARK: - Text

    /// Attributed string of a text layer.
    static func attributedText(_ content: TextLayerContent) -> NSAttributedString {
        let font = UIFont(name: content.font.postScriptName, size: content.fontSize)
            ?? .systemFont(ofSize: content.fontSize, weight: .bold)
        let paragraph = NSMutableParagraphStyle()
        switch content.alignment {
        case .leading: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .trailing: paragraph.alignment = .right
        }
        return NSAttributedString(string: content.text, attributes: [
            .font: font,
            .foregroundColor: content.color.uiColor,
            .paragraphStyle: paragraph
        ])
    }

    /// Height the text needs inside its box width, in page points.
    static func textHeight(_ content: TextLayerContent) -> Double {
        let bounds = attributedText(content).boundingRect(
            with: CGSize(width: content.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return max(bounds.height.rounded(.up), content.fontSize)
    }

    /// The text box alone, used by the canvas while the layer is selected.
    static func textImage(_ content: TextLayerContent, scale: CGFloat) -> UIImage {
        let size = CGSize(width: content.width, height: content.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            attributedText(content).draw(with: CGRect(origin: .zero, size: size),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading],
                                         context: nil)
        }
    }

    // MARK: - Private

    private static func draw(_ layer: ZineLayer, in document: ZineDocument, context: CGContext, scale: CGFloat) {
        let alpha = CGFloat(layer.opacity)
        let blend = layer.blendMode.cgBlendMode

        switch layer.content {
        case .drawing:
            let drawing = document.drawing(for: layer.id)
            guard !drawing.strokes.isEmpty else { return }
            var image = drawingImage(drawing, rect: ZineFormat.pageRect, scale: scale)
            if layer.filter != .none {
                image = ImageProcessing.apply(layer.filter, to: image)
            }
            image.draw(in: ZineFormat.pageRect, blendMode: blend, alpha: alpha)

        case .image(let content):
            guard let image = document.image(named: content.assetName, filter: layer.filter) else { return }
            drawTransformed(image, width: content.width, height: content.height,
                            transform: content.transform, blend: blend, alpha: alpha, context: context)

        case .text(let content):
            // Text is drawn as an image at the output scale so filters can apply.
            var image = textImage(content, scale: scale * CGFloat(content.transform.scale))
            if layer.filter != .none {
                image = ImageProcessing.apply(layer.filter, to: image)
            }
            drawTransformed(image, width: content.width, height: content.height,
                            transform: content.transform, blend: blend, alpha: alpha, context: context)
        }
    }

    private static func drawTransformed(_ image: UIImage, width: Double, height: Double,
                                        transform: LayerTransform, blend: CGBlendMode,
                                        alpha: CGFloat, context: CGContext) {
        context.saveGState()
        context.translateBy(x: transform.centerX, y: transform.centerY)
        context.rotate(by: transform.rotation)
        context.scaleBy(x: transform.scale, y: transform.scale)
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        image.draw(in: rect, blendMode: blend, alpha: alpha)
        context.restoreGState()
    }
}
