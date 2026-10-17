//
//  PreviewData.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import PencilKit
import UIKit

/// Sample data for `#Preview`s.
@MainActor
enum PreviewData {
    // MARK: Repository

    /// A repository in a throwaway folder with two blank zines.
    static func repository() -> FileZineRepository {
        let repository = FileZineRepository(rootURL: temporaryRoot())
        _ = try? repository.createZine(title: "Zine")
        _ = try? repository.createZine(title: "Cadernos de rua")
        return repository
    }

    static func galleryViewModel() -> GalleryViewModel {
        GalleryViewModel(repository: repository())
    }

    // MARK: Documents

    /// A zine with a scribble on the cover and on page 1.
    static func document() -> ZineDocument {
        let zine = Zine.blank(title: "Zine de exemplo")
        let package = ZinePackage(url: temporaryRoot().appendingPathComponent("\(zine.id.uuidString).zine"))
        try? package.writeManifest(zine)

        for pageIndex in [0, 1] {
            guard let layer = zine.pages[pageIndex].layers.first else { continue }
            let drawing = sampleDrawing(seed: Double(pageIndex))
            try? package.writeDrawingData(drawing.dataRepresentation(), for: layer.id)
        }
        return try! ZineDocument(package: package)
    }

    /// An editor view model for previews.
    static func editorViewModel(isPageDrawerOpen: Bool = false) -> EditorViewModel {
        let viewModel = EditorViewModel(document: document())
        viewModel.isPageDrawerOpen = isPageDrawerOpen
        return viewModel
    }

    // MARK: Drawings

    /// A hand-drawn-looking spiral, so pages are not blank.
    static func sampleDrawing(seed: Double = 0) -> PKDrawing {
        let center = CGPoint(x: ZineFormat.pageSize.width / 2, y: ZineFormat.pageSize.height / 2)
        let points = (0..<240).map { i -> PKStrokePoint in
            let t = Double(i) / 12 + seed
            let radius = 40 + Double(i) * 1.6
            let location = CGPoint(x: center.x + cos(t) * radius, y: center.y + sin(t) * radius)
            return PKStrokePoint(location: location, timeOffset: Double(i) * 0.01,
                                 size: CGSize(width: 12, height: 12), opacity: 1,
                                 force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: path)
        return PKDrawing(strokes: [stroke])
    }

    /// The UIKit canvas alone, with the sample scribble loaded.
    static func canvasHostView() -> PageCanvasHostView {
        let view = PageCanvasHostView()
        view.backgroundColor = .darkGray
        view.load(drawing: sampleDrawing())
        return view
    }

    // MARK: Private

    private static func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("8CutPreview-\(UUID().uuidString)", isDirectory: true)
    }
}
