//
//  ZineExporter.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit

/// Builds the export files: print sheet PDF, pages PDF and page images.
@MainActor
enum ZineExporter {
    /// Pixels per page point for exports. Pages come out 1250 px wide,
    /// about 430 dpi on an A4 sheet.
    static let exportScale: CGFloat = 1.25

    /// Size of one page on an A4 sheet (1/8 of it), in PDF points.
    static let pagePDFSize = CGSize(width: 841.89 / 4, height: 595.28 / 2)

    // MARK: - Pages

    /// All pages rendered in reading order.
    static func pageImages(of document: ZineDocument, scale: CGFloat = exportScale) -> [UIImage] {
        document.pages.map { PageRenderer.render(page: $0, in: document, scale: scale) }
    }

    // MARK: - Print sheet

    /// PDF with the 8 pages on one landscape sheet, ready to print, cut and fold.
    static func printSheetPDF(pages: [UIImage], paper: PaperSize, showsGuides: Bool) -> Data {
        let bounds = CGRect(origin: .zero, size: paper.size)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            drawSheet(pages: pages, paper: paper, showsGuides: showsGuides, in: context.cgContext)
        }
    }

    /// Small image of the print sheet for the export screen.
    static func sheetPreview(pages: [UIImage], paper: PaperSize, showsGuides: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: paper.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: paper.size))
            drawSheet(pages: pages, paper: paper, showsGuides: showsGuides, in: context.cgContext)
        }
    }

    /// Draws each page in its cell. Pages of the top row are rotated 180°.
    static func drawSheet(pages: [UIImage], paper: PaperSize, showsGuides: Bool, in context: CGContext) {
        let sheet = paper.size
        for slot in PrintLayout.slots where pages.indices.contains(slot.pageIndex) {
            let cell = PrintLayout.cell(for: slot, sheet: sheet)
            let rect = aspectFit(ZineFormat.pageSize, in: cell)
            context.saveGState()
            if slot.isUpsideDown {
                context.translateBy(x: cell.midX, y: cell.midY)
                context.rotate(by: .pi)
                context.translateBy(x: -cell.midX, y: -cell.midY)
            }
            pages[slot.pageIndex].draw(in: rect)
            context.restoreGState()
        }

        guard showsGuides else { return }
        context.saveGState()
        context.setStrokeColor(UIColor.gray.cgColor)
        context.setLineWidth(0.5)
        context.setLineDash(phase: 0, lengths: [1, 3])
        for line in PrintLayout.foldLines(sheet: sheet) {
            context.move(to: line.start)
            context.addLine(to: line.end)
        }
        context.strokePath()

        let cut = PrintLayout.cutLine(sheet: sheet)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.75)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.move(to: cut.start)
        context.addLine(to: cut.end)
        context.strokePath()
        context.restoreGState()

        let label = NSAttributedString(string: "✂︎ corte", attributes: [
            .font: UIFont.systemFont(ofSize: 7),
            .foregroundColor: UIColor.black
        ])
        label.draw(at: CGPoint(x: cut.start.x + 4, y: cut.start.y - 10))
    }

    // MARK: - Pages PDF

    /// PDF with one page per zine page, in reading order.
    static func pagesPDF(pages: [UIImage]) -> Data {
        let bounds = CGRect(origin: .zero, size: pagePDFSize)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for page in pages {
                context.beginPage()
                page.draw(in: aspectFit(ZineFormat.pageSize, in: bounds))
            }
        }
    }

    // MARK: - Files

    /// Writes data to a temporary file to hand to the share sheet.
    static func temporaryFile(_ data: Data, name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Title usable as a file name.
    static func fileName(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Zine" : cleaned
    }

    // MARK: - Private

    private static func aspectFit(_ size: CGSize, in rect: CGRect) -> CGRect {
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }
}
