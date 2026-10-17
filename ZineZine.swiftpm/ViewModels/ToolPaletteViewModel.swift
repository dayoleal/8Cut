//
//  ToolPaletteViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import UIKit
import Observation

/// State of the tool tray: selected instrument, color, widths and modes.
///
/// Each instrument remembers its own width, like a real pencil case.
@MainActor
@Observable
final class ToolPaletteViewModel {
    /// The instrument in hand.
    var selectedTool: DrawingTool = .ballpoint {
        didSet {
            if selectedTool.usesColor { lastInkTool = selectedTool }
        }
    }
    var color: RGBAColor = .black
    /// Ink opacity, `0.05...1`.
    var opacity: Double = 1
    /// Normalized width (`0...1`) per instrument.
    var widths: [DrawingTool: Double] = [
        .pencil: 0.2, .fountainPen: 0.2, .marker: 0.4, .watercolor: 0.4,
        .ink: 0.15, .crayon: 0.35, .ballpoint: 0.15, .eraser: 0.3
    ]
    var isRulerActive = false
    /// When `false`, only Apple Pencil draws and fingers pan/zoom (palm rejection).
    var allowsFingerDrawing = true

    /// Whether the "…" options popover is shown.
    var isShowingOptions = false

    /// Quick colors of the swatch grid (the sixth cell is the system picker).
    let swatches: [RGBAColor] = [
        RGBAColor(red: 1, green: 1, blue: 1),
        RGBAColor(red: 0.2, green: 0.47, blue: 0.96),
        RGBAColor(red: 0.45, green: 0.82, blue: 0.45),
        RGBAColor(red: 0.98, green: 0.81, blue: 0.29),
        RGBAColor(red: 0.9, green: 0.26, blue: 0.25)
    ]

    /// Tray items in display order.
    var trayItems: [TrayItem] { TrayItem.all }

    /// Last inking instrument, restored when leaving the eraser.
    private(set) var lastInkTool: DrawingTool = .ballpoint

    // MARK: Derived state

    /// Width of the selected instrument.
    var width: Double {
        get { widths[selectedTool] ?? 0.2 }
        set { widths[selectedTool] = min(max(newValue, 0), 1) }
    }

    /// Whether opacity applies to the instrument in hand.
    var isOpacityEnabled: Bool { selectedTool.usesColor }

    func isSelected(_ tool: DrawingTool) -> Bool { selectedTool == tool }

    /// Height of a tray artwork drawn at `width`, keeping the asset's aspect ratio.
    ///
    /// - Parameters:
    ///   - item: The tray item.
    ///   - width: Rendered width, in points.
    func artworkHeight(for item: TrayItem, width: CGFloat) -> CGFloat {
        guard let size = UIImage(named: item.assetName)?.size, size.width > 0 else { return width * 4 }
        return width * size.height / size.width
    }

    /// Whether a tray item is lifted: the instrument in hand, or the ruler while it is on.
    func isRaised(_ item: TrayItem) -> Bool {
        switch item {
        case .tool(let tool): return isSelected(tool)
        case .ruler: return isRulerActive
        }
    }
    func isSelected(_ swatch: RGBAColor) -> Bool { color == swatch }

    /// Snapshot consumed by the canvas.
    var configuration: ToolConfiguration {
        var inkColor = color
        inkColor.alpha = opacity
        return ToolConfiguration(tool: selectedTool, color: inkColor, normalizedWidth: width)
    }

    // MARK: Actions

    func select(_ tool: DrawingTool) {
        selectedTool = tool
    }

    /// Picks a color; leaves the eraser if it was in hand.
    func select(_ color: RGBAColor) {
        self.color = color
        if !selectedTool.usesColor { selectedTool = lastInkTool }
    }

    /// Picks an instrument, or toggles the ruler.
    func select(_ item: TrayItem) {
        switch item {
        case .tool(let tool): select(tool)
        case .ruler: toggleRuler()
        }
    }

    func showOptions() {
        isShowingOptions = true
    }

    func toggleRuler() {
        isRulerActive.toggle()
    }

    /// Apple Pencil double tap: switches between the last ink and the eraser.
    func toggleEraser() {
        selectedTool = selectedTool == .eraser ? lastInkTool : .eraser
    }
}
