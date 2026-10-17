//
//  DrawingTool.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import CoreGraphics
import PencilKit

/// A drawing instrument of the tool tray, backed by a PencilKit tool.
enum DrawingTool: String, CaseIterable, Identifiable, Sendable {
    case pencil, fountainPen, marker, watercolor, ink, crayon, ballpoint, eraser

    var id: String { rawValue }


    /// Localized name, used for accessibility.
    var displayName: String {
        switch self {
        case .pencil: return "Lápis"
        case .fountainPen: return "Caneta-tinteiro"
        case .marker: return "Marca-texto"
        case .watercolor: return "Pincel"
        case .ink: return "Nanquim"
        case .crayon: return "Giz de cera"
        case .ballpoint: return "Esferográfica"
        case .eraser: return "Borracha"
        }
    }

    /// Illustration in `Assets.xcassets/tools`.
    var assetName: String {
        switch self {
        case .pencil: return "pencil"
        case .fountainPen: return "pen"
        case .marker: return "highlighter"
        case .watercolor: return "brush"
        case .ink: return "nanquin"
        case .crayon: return "crayon"
        case .ballpoint: return "spherographic"
        case .eraser: return "eraser"
        }
    }

    /// The PencilKit ink, or `nil` for the eraser.
    var inkType: PKInkingTool.InkType? {
        switch self {
        case .pencil: return .pencil
        case .fountainPen: return .fountainPen
        case .marker: return .marker
        case .watercolor: return .watercolor
        case .ink: return .monoline
        case .crayon: return .crayon
        case .ballpoint: return .pen
        case .eraser: return nil
        }
    }

    /// Whether color and opacity apply to this tool.
    var usesColor: Bool { inkType != nil }
}

/// An item of the tool tray: an instrument or the ruler toggle.
enum TrayItem: Hashable, Identifiable, Sendable {
    case tool(DrawingTool)
    /// Shows PencilKit's ruler on top of the current instrument.
    case ruler

    var id: String {
        switch self {
        case .tool(let tool): return tool.rawValue
        case .ruler: return "ruler"
        }
    }

    /// Tray order, as in the design.
    static let all: [TrayItem] = [
        .tool(.pencil), .tool(.fountainPen), .tool(.marker), .tool(.watercolor),
        .tool(.ink), .tool(.crayon), .tool(.ballpoint), .ruler, .tool(.eraser)
    ]

    var assetName: String {
        switch self {
        case .tool(let tool): return tool.assetName
        case .ruler: return "ruler"
        }
    }

    var displayName: String {
        switch self {
        case .tool(let tool): return tool.displayName
        case .ruler: return "Régua"
        }
    }

    /// Width of the illustration in the tray on the 11-inch iPad, in points.
    /// Height follows the artwork's aspect ratio.
    var designWidth: CGFloat {
        switch self {
        case .tool(.pencil): return 21
        case .tool(.fountainPen): return 25
        case .tool(.marker): return 50
        case .tool(.watercolor): return 27.5
        case .tool(.ink): return 22.5
        case .tool(.crayon): return 24
        case .tool(.ballpoint): return 20
        case .ruler: return 41
        case .tool(.eraser): return 73.5
        }
    }
}

/// An immutable snapshot of everything the canvas needs to build its `PKTool`.
///
/// Acts as a small factory (``makePKTool()``) and is `Equatable`, so the canvas
/// only reconfigures PencilKit when something actually changed.
struct ToolConfiguration: Equatable, Sendable {
    var tool: DrawingTool
    var color: RGBAColor
    /// `0...1`, mapped onto each tool's valid width range.
    var normalizedWidth: Double

    /// Builds the PencilKit tool for this configuration.
    @MainActor
    func makePKTool() -> PKTool {
        guard let inkType = tool.inkType else {
            return PKEraserTool(.bitmap, width: 8 + normalizedWidth * 92)
        }
        let range = inkType.validWidthRange
        let width = range.lowerBound + (range.upperBound - range.lowerBound) * normalizedWidth
        return PKInkingTool(inkType, color: color.uiColor, width: width)
    }
}
