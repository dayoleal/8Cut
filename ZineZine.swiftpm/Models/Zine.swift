//
//  Zine.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import CoreGraphics

// MARK: - Format

/// Constants of the 8-page zine format.
///
/// One landscape sheet is split into 4 columns and 2 rows, so a page is 1/8 of the
/// sheet (74.25 × 105 mm on A4). Page content uses the coordinates of ``pageSize``.
enum ZineFormat {
    /// Number of pages in reading order: `0` is the cover, `1...6` the inside
    /// pages and `7` the back cover.
    static let pageCount = 8

    /// Logical size of a single page, in points.
    static let pageSize = CGSize(width: 1000, height: 1414)

    /// Logical bounds of a single page.
    static var pageRect: CGRect { CGRect(origin: .zero, size: pageSize) }

    /// Width divided by height of a page.
    static var pageAspectRatio: CGFloat { pageSize.width / pageSize.height }

    /// Current version written to `manifest.json`.
    static let currentVersion = 1

    /// Page name shown in the UI ("Capa", "Pág 1"..."Pág 6", "Contracapa").
    ///
    /// - Parameter index: Page index in reading order.
    /// - Returns: The page name.
    static func pageLabel(_ index: Int) -> String {
        switch index {
        case 0: return "Capa"
        case pageCount - 1: return "Contracapa"
        default: return "Pág \(index)"
        }
    }
}

// MARK: - Zine

/// Zine saved in `manifest.json`. Drawings and images are stored in separate
/// files of the ``ZinePackage``.
struct Zine: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var formatVersion: Int
    /// Always ``ZineFormat/pageCount`` pages, in reading order.
    var pages: [ZinePage]

    /// Creates an empty zine with one drawing layer per page.
    ///
    /// - Parameter title: The initial title.
    static func blank(title: String) -> Zine {
        let now = Date()
        return Zine(
            id: UUID(),
            title: title,
            createdAt: now,
            modifiedAt: now,
            formatVersion: ZineFormat.currentVersion,
            pages: (0..<ZineFormat.pageCount).map { _ in ZinePage.blank() }
        )
    }
}

// MARK: - Page

/// A page with its paper color and layers.
struct ZinePage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var paperColor: RGBAColor
    /// Index `0` is the bottom layer.
    var layers: [ZineLayer]
    /// Applied over the whole page, above all layers.
    var filter: LayerFilter = .none

    /// A white page with a single drawing layer.
    static func blank() -> ZinePage {
        ZinePage(id: UUID(), paperColor: .paper, layers: [.drawing(name: "Desenho")])
    }
}

// MARK: - Layer

/// A layer of a page.
struct ZineLayer: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var content: LayerContent
    var isVisible: Bool = true
    var isLocked: Bool = false
    /// `0...1`.
    var opacity: Double = 1
    var blendMode: LayerBlendMode = .normal
    /// Applied when the page is rendered. The original content is kept.
    var filter: LayerFilter = .none

    /// Creates an empty drawing layer.
    static func drawing(name: String) -> ZineLayer {
        ZineLayer(id: UUID(), name: name, content: .drawing)
    }

    /// Whether the layer holds PencilKit strokes.
    var isDrawing: Bool {
        if case .drawing = content { return true }
        return false
    }

    var isImage: Bool {
        if case .image = content { return true }
        return false
    }

    var isText: Bool {
        if case .text = content { return true }
        return false
    }

    /// Size and transform of image and text layers. `nil` for drawings.
    var frame: LayerFrame? {
        switch content {
        case .drawing: return nil
        case .image(let image): return LayerFrame(width: image.width, height: image.height, transform: image.transform)
        case .text(let text): return LayerFrame(width: text.width, height: text.height, transform: text.transform)
        }
    }

    /// Replaces the transform of an image or text layer.
    mutating func setTransform(_ transform: LayerTransform) {
        switch content {
        case .drawing:
            break
        case .image(var image):
            image.transform = transform
            content = .image(image)
        case .text(var text):
            text.transform = transform
            content = .text(text)
        }
    }
}

extension ZinePage {
    private enum CodingKeys: String, CodingKey {
        case id, paperColor, layers, filter
    }

    /// Reads pages saved before `filter` existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        paperColor = try container.decode(RGBAColor.self, forKey: .paperColor)
        layers = try container.decode([ZineLayer].self, forKey: .layers)
        filter = try container.decodeIfPresent(LayerFilter.self, forKey: .filter) ?? .none
    }
}

extension ZineLayer {
    private enum CodingKeys: String, CodingKey {
        case id, name, content, isVisible, isLocked, opacity, blendMode, filter
    }

    /// Reads layers saved before `filter` existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        content = try container.decode(LayerContent.self, forKey: .content)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        blendMode = try container.decodeIfPresent(LayerBlendMode.self, forKey: .blendMode) ?? .normal
        filter = try container.decodeIfPresent(LayerFilter.self, forKey: .filter) ?? .none
    }
}

/// Size of a movable layer and its transform.
struct LayerFrame: Hashable, Sendable {
    var width: Double
    var height: Double
    var transform: LayerTransform
}

/// Content of a layer.
enum LayerContent: Codable, Hashable, Sendable {
    /// PencilKit strokes, stored at `drawings/<layer id>.drawing`.
    case drawing
    /// An imported image (collage), stored at `assets/<assetName>`.
    case image(ImageLayerContent)
    /// A text box.
    case text(TextLayerContent)
}

/// Text box and its position on the page.
struct TextLayerContent: Codable, Hashable, Sendable {
    var text: String
    var font: TextFont
    /// Font size in page points.
    var fontSize: Double
    var color: RGBAColor
    var alignment: TextAlignmentOption
    /// Box width in page points. Text wraps inside it.
    var width: Double
    /// Box height in page points, updated when the text changes.
    var height: Double
    var transform: LayerTransform
}

/// Fonts available for text layers.
enum TextFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case typewriter, marker, condensed, serif, mono, hand

    var id: String { rawValue }

    /// PostScript name of the font.
    var postScriptName: String {
        switch self {
        case .typewriter: return "AmericanTypewriter"
        case .marker: return "MarkerFelt-Wide"
        case .condensed: return "AvenirNextCondensed-Heavy"
        case .serif: return "Georgia-Bold"
        case .mono: return "Menlo-Regular"
        case .hand: return "Noteworthy-Bold"
        }
    }

    /// Name shown in the text editor.
    var displayName: String {
        switch self {
        case .typewriter: return "Máquina de escrever"
        case .marker: return "Marcador"
        case .condensed: return "Condensada"
        case .serif: return "Serifa"
        case .mono: return "Mono"
        case .hand: return "Manuscrita"
        }
    }
}

enum TextAlignmentOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading, center, trailing

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
}

/// Filter applied to a layer when it is rendered.
enum LayerFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, xerox, halftone, noir, cyanotype, redBlue, negative

    var id: String { rawValue }

    /// Name shown in the layers drawer.
    var displayName: String {
        switch self {
        case .none: return "Nenhum"
        case .xerox: return "Xerox"
        case .halftone: return "Retícula"
        case .noir: return "Preto e branco"
        case .cyanotype: return "Cianotipia"
        case .redBlue: return "Vermelho e azul"
        case .negative: return "Negativo"
        }
    }
}

/// Imported image and its position on the page.
struct ImageLayerContent: Codable, Hashable, Sendable {
    var assetName: String
    /// Width in page points when `transform.scale == 1`.
    var width: Double
    /// Height in page points when `transform.scale == 1`.
    var height: Double
    var transform: LayerTransform
}

/// Position, scale and rotation around the content center.
struct LayerTransform: Codable, Hashable, Sendable {
    var centerX: Double
    var centerY: Double
    var scale: Double = 1
    /// In radians.
    var rotation: Double = 0
}

/// Blend mode of a layer.
enum LayerBlendMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorBurn, colorDodge, difference

    var id: String { rawValue }

    /// Name shown in the layer panel.
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiplicar"
        case .screen: return "Tela"
        case .overlay: return "Sobrepor"
        case .darken: return "Escurecer"
        case .lighten: return "Clarear"
        case .colorBurn: return "Superexposição de cor"
        case .colorDodge: return "Subexposição de cor"
        case .difference: return "Diferença"
        }
    }

    /// The equivalent Core Graphics blend mode.
    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorBurn: return .colorBurn
        case .colorDodge: return .colorDodge
        case .difference: return .difference
        }
    }
}
