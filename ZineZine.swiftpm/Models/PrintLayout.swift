//
//  PrintLayout.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import CoreGraphics

/// Paper sizes for the print sheet, in PDF points (1/72 inch), landscape.
enum PaperSize: String, CaseIterable, Identifiable, Sendable {
    case a4, letter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Carta"
        }
    }

    /// Landscape size in points.
    var size: CGSize {
        switch self {
        case .a4: return CGSize(width: 841.89, height: 595.28)
        case .letter: return CGSize(width: 792, height: 612)
        }
    }
}

/// Position of a page on the print sheet.
struct PrintSlot: Sendable {
    /// Page index in reading order (0 = cover, 7 = back cover).
    let pageIndex: Int
    /// Column from the left, `0...3`.
    let column: Int
    /// Row from the top, `0...1`.
    let row: Int
    /// Pages of the top row are printed upside down.
    var isUpsideDown: Bool { row == 0 }
}

/// A straight guide line on the sheet.
struct PrintLine: Sendable {
    let start: CGPoint
    let end: CGPoint
}

/// Layout of an 8-page zine on one landscape sheet.
///
/// ```
/// ┌──────┬──────┬──────┬──────┐
/// │  5 ↻ │  4 ↻ │  3 ↻ │  2 ↻ │   top row, upside down
/// ├──────┼──────┴──────┼──────┤   ← cut only between the two middle columns
/// │  6   │  7   │ back │ cover│
/// └──────┴──────┴──────┴──────┘
/// ```
/// Pages 2 to 7 are the inside pages ("Pág 1" to "Pág 6" in the app).
enum PrintLayout {
    static let columns = 4
    static let rows = 2

    static let slots: [PrintSlot] = [
        PrintSlot(pageIndex: 4, column: 0, row: 0),
        PrintSlot(pageIndex: 3, column: 1, row: 0),
        PrintSlot(pageIndex: 2, column: 2, row: 0),
        PrintSlot(pageIndex: 1, column: 3, row: 0),
        PrintSlot(pageIndex: 5, column: 0, row: 1),
        PrintSlot(pageIndex: 6, column: 1, row: 1),
        PrintSlot(pageIndex: 7, column: 2, row: 1),
        PrintSlot(pageIndex: 0, column: 3, row: 1)
    ]

    /// Cell of a slot on a sheet of the given size.
    static func cell(for slot: PrintSlot, sheet: CGSize) -> CGRect {
        let width = sheet.width / CGFloat(columns)
        let height = sheet.height / CGFloat(rows)
        return CGRect(x: CGFloat(slot.column) * width, y: CGFloat(slot.row) * height,
                      width: width, height: height)
    }

    /// The only cut: horizontal, in the middle of the sheet, across the two middle columns.
    static func cutLine(sheet: CGSize) -> PrintLine {
        PrintLine(start: CGPoint(x: sheet.width / 4, y: sheet.height / 2),
                  end: CGPoint(x: sheet.width * 3 / 4, y: sheet.height / 2))
    }

    /// Fold lines: the three vertical lines and the parts of the horizontal line that are not cut.
    static func foldLines(sheet: CGSize) -> [PrintLine] {
        var lines = (1..<columns).map { column in
            let x = sheet.width * CGFloat(column) / CGFloat(columns)
            return PrintLine(start: CGPoint(x: x, y: 0), end: CGPoint(x: x, y: sheet.height))
        }
        let middle = sheet.height / 2
        lines.append(PrintLine(start: CGPoint(x: 0, y: middle), end: CGPoint(x: sheet.width / 4, y: middle)))
        lines.append(PrintLine(start: CGPoint(x: sheet.width * 3 / 4, y: middle), end: CGPoint(x: sheet.width, y: middle)))
        return lines
    }
}
