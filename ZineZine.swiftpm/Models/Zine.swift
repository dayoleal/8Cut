//
//  Zine.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import CoreGraphics

// MARK: - Format

/// Fixed geometry and conventions of an 8-page, one-sheet zine.
///
/// A sheet (A4 or Letter, landscape) is split into 4 columns × 2 rows, so every
/// page is one eighth of the sheet. On A4 that is 74.25 × 105 mm, a 1 : √2 portrait
/// page. All page content is stored in this logical coordinate space.
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

    /// User-facing name of a page ("Capa", "Pág 1"..."Pág 6", "Contracapa").
    ///
    /// - Parameter index: Page index in reading order.
    /// - Returns: A short localized label.
    static func pageLabel(_ index: Int) -> String {
        switch index {
        case 0: return "Capa"
        case pageCount - 1: return "Contracapa"
        default: return "Pág \(index)"
        }
    }
}

// MARK: - Zine

/// The persisted description of a zine — the content of `manifest.json`.
///
/// Heavy content (PencilKit strokes and imported images) lives in separate files
/// inside the package and is referenced by layer ID or asset name.
/// See ``ZinePackage``.
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

/// A single page: paper color plus an ordered stack of layers.
struct ZinePage: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var paperColor: RGBAColor
    /// Composition order — index `0` is the bottom-most layer.
    var layers: [ZineLayer]

    /// A white page with a single drawing layer.
    static func blank() -> ZinePage {
        ZinePage(id: UUID(), paperColor: .paper, layers: [.drawing(name: "Desenho")])
    }
}

// MARK: - Layer

/// A layer of a page and its compositing attributes.
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

/// What a layer contains.
enum LayerContent: Codable, Hashable, Sendable {
    /// PencilKit strokes, stored at `drawings/<layer id>.drawing`.
    case drawing
    /// An imported image (collage), stored at `assets/<assetName>`.
    case image(ImageLayerContent)
}

/// Placement of an imported image on the page.
struct ImageLayerContent: Codable, Hashable, Sendable {
    var assetName: String
    /// Width in page points when `transform.scale == 1`.
    var width: Double
    /// Height in page points when `transform.scale == 1`.
    var height: Double
    var transform: LayerTransform
}

/// A similarity transform applied around the content's center.
struct LayerTransform: Codable, Hashable, Sendable {
    var centerX: Double
    var centerY: Double
    var scale: Double = 1
    /// In radians.
    var rotation: Double = 0
}

/// Compositing mode of a layer, mapped 1:1 to Core Graphics.
enum LayerBlendMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorBurn, colorDodge, difference

    var id: String { rawValue }

    /// Localized name shown in the layer panel.
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
