//
//  ExportViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import Observation

/// What the export screen produces.
enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case printSheet, pagesPDF, images

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .printSheet: return "Folha para imprimir"
        case .pagesPDF: return "PDF das páginas"
        case .images: return "Imagens"
        }
    }

    var details: String {
        switch self {
        case .printSheet: return "As 8 páginas numa folha, na posição certa para cortar e dobrar."
        case .pagesPDF: return "Uma página por folha, na ordem de leitura."
        case .images: return "Um PNG por página."
        }
    }
}

/// Files for the share sheet, used with `.sheet(item:)`.
struct ShareFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// View model of the export screen.
@MainActor
@Observable
final class ExportViewModel: Identifiable {
    let id = UUID()
    let document: ZineDocument

    var format: ExportFormat = .printSheet
    var paper: PaperSize = .a4
    var showsGuides = true
    var isExporting = false
    var sharedFiles: ShareFiles?
    var errorMessage: String?

    @ObservationIgnored private var pages: [UIImage]?
    @ObservationIgnored private var previewCache: (paper: PaperSize, showsGuides: Bool, image: UIImage)?

    init(document: ZineDocument) {
        self.document = document
    }

    var title: String { document.zine.title }

    /// Preview of the print sheet.
    var sheetPreview: UIImage {
        if let cache = previewCache, cache.paper == paper, cache.showsGuides == showsGuides {
            return cache.image
        }
        let small = previewPages
        let image = ZineExporter.sheetPreview(pages: small, paper: paper, showsGuides: showsGuides)
        previewCache = (paper, showsGuides, image)
        return image
    }

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    // MARK: Actions

    /// Builds the files of the selected format and opens the share sheet.
    func export() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            // Let the progress indicator appear before the rendering starts.
            await Task.yield()
            defer { isExporting = false }
            do {
                sharedFiles = ShareFiles(urls: try makeFiles())
            } catch {
                errorMessage = "Não foi possível exportar: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Private

    @ObservationIgnored private var previewPagesCache: [UIImage]?

    private var previewPages: [UIImage] {
        if let cached = previewPagesCache { return cached }
        let images = ZineExporter.pageImages(of: document, scale: 0.3)
        previewPagesCache = images
        return images
    }

    private func exportPages() -> [UIImage] {
        if let pages { return pages }
        let images = ZineExporter.pageImages(of: document)
        pages = images
        return images
    }

    private func makeFiles() throws -> [URL] {
        let name = ZineExporter.fileName(for: title)
        switch format {
        case .printSheet:
            let data = ZineExporter.printSheetPDF(pages: exportPages(), paper: paper, showsGuides: showsGuides)
            return [try ZineExporter.temporaryFile(data, name: "\(name) - impressão \(paper.displayName).pdf")]
        case .pagesPDF:
            let data = ZineExporter.pagesPDF(pages: exportPages())
            return [try ZineExporter.temporaryFile(data, name: "\(name).pdf")]
        case .images:
            return try exportPages().enumerated().compactMap { index, image in
                guard let data = image.pngData() else { return nil }
                let label = ZineFormat.pageLabel(index)
                return try ZineExporter.temporaryFile(data, name: "\(name) - \(index + 1) \(label).png")
            }
        }
    }
}
