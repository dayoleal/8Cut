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

    /// Creates an empty drawing layer.
    static func drawing(name: String) -> ZineLayer {
        ZineLayer(id: UUID(), name: name, content: .drawing)
    }

    /// Whether the layer holds PencilKit strokes.
    var isDrawing: Bool {
        if case .drawing = content { return true }
        return false
    }
}

/// Content of a layer.
enum LayerContent: Codable, Hashable, Sendable {
    /// PencilKit strokes, stored at `drawings/<layer id>.drawing`.
    case drawing
    /// An imported image (collage), stored at `assets/<assetName>`.
    case image(ImageLayerContent)
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
