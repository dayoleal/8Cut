//
//  ZineDocument.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import PencilKit
import Observation

/// An open zine: the in-memory model shared by the reader and the editor.
///
/// Owns the manifest, the decoded drawings and images, the ``EditHistory`` and
/// autosaving. View models read from and write to it; views never touch it
/// directly except through their view model.
@MainActor
@Observable
final class ZineDocument {
    /// Where the document is stored.
    let package: ZinePackage
    /// Current manifest.
    private(set) var zine: Zine
    /// Undo/redo stack of this session.
    let history = EditHistory()

    /// Incremented on every content change; observers use it to recompose pages.
    private(set) var contentRevision = 0
    /// Small renders of each page, keyed by page ID.
    private(set) var pageThumbnails: [UUID: UIImage] = [:]
    /// Last error raised while saving, if any.
    private(set) var lastSaveError: String?

    /// Called when undo/redo replaces the drawing of a layer, so a live canvas
    /// showing that layer can reload its `PKDrawing`.
    @ObservationIgnored var onDrawingReplaced: ((UUID) -> Void)?

    @ObservationIgnored private var drawings: [UUID: PKDrawing] = [:]
    @ObservationIgnored private var drawingRevisions: [UUID: Int] = [:]
    @ObservationIgnored private var images: [String: UIImage] = [:]
    @ObservationIgnored private var dirtyDrawings: Set<UUID> = []
    @ObservationIgnored private var needsSave = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnailTask: Task<Void, Never>?
    @ObservationIgnored private var staleThumbnails: Set<UUID> = []
    @ObservationIgnored private var readerImages: [Int: (revision: Int, image: UIImage)] = [:]

    // MARK: - Lifecycle

    /// Loads a document from disk.
    ///
    /// - Parameter package: The package to read.
    /// - Throws: If the manifest is missing or cannot be decoded.
    init(package: ZinePackage) throws {
        self.package = package
        let zine = try package.readManifest()
        self.zine = zine

        for page in zine.pages {
            for layer in page.layers where layer.isDrawing {
                if let data = package.readDrawingData(for: layer.id),
                   let drawing = try? PKDrawing(data: data) {
                    drawings[layer.id] = drawing
                }
            }
        }
        staleThumbnails = Set(zine.pages.map(\.id))
        scheduleThumbnails(delay: 0)
    }

    // MARK: - Reading

    /// Pages in reading order.
    var pages: [ZinePage] { zine.pages }

    /// The page at `index`.
    func page(at index: Int) -> ZinePage { zine.pages[index] }

    /// The strokes of a drawing layer (empty if it has none yet).
    func drawing(for layerID: UUID) -> PKDrawing {
        drawings[layerID] ?? PKDrawing()
    }

    /// Changes whenever the drawing of the layer changes (stroke, undo, redo).
    func drawingRevision(for layerID: UUID) -> Int {
        drawingRevisions[layerID] ?? 0
    }

    /// An imported image, loaded lazily from the package and cached.
    func image(named name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let image = UIImage(contentsOfFile: package.assetURL(named: name).path) else { return nil }
        images[name] = image
        return image
    }

    /// The page rendered at reading resolution (700 px wide), cached per revision.
    func readerImage(for index: Int) -> UIImage {
        if let cached = readerImages[index], cached.revision == contentRevision {
            return cached.image
        }
        let image = PageRenderer.render(page: zine.pages[index], in: self, scale: 0.7)
        readerImages[index] = (contentRevision, image)
        return image
    }

    /// Every page rendered at 1500 px wide, for sharing.
    func shareImages() -> [UIImage] {
        zine.pages.map { PageRenderer.render(page: $0, in: self, scale: 1.5) }
    }

    // MARK: - Drawing edits

    /// Records the canvas state at the end of a stroke (or erase).
    ///
    /// - Parameters:
    ///   - newDrawing: The drawing after the stroke.
    ///   - layerID: The edited drawing layer.
    ///   - pageIndex: The page that contains the layer.
    func commitDrawing(_ newDrawing: PKDrawing, layerID: UUID, pageIndex: Int) {
        let oldDrawing = drawing(for: layerID)
        applyDrawing(newDrawing, layerID: layerID, pageIndex: pageIndex)
        history.record("Traço", pageIndex: pageIndex,
            undo: { [weak self] in
                self?.applyDrawing(oldDrawing, layerID: layerID, pageIndex: pageIndex)
                self?.onDrawingReplaced?(layerID)
            },
            redo: { [weak self] in
                self?.applyDrawing(newDrawing, layerID: layerID, pageIndex: pageIndex)
                self?.onDrawingReplaced?(layerID)
            })
    }

    private func applyDrawing(_ drawing: PKDrawing, layerID: UUID, pageIndex: Int) {
        drawings[layerID] = drawing
        drawingRevisions[layerID, default: 0] += 1
        dirtyDrawings.insert(layerID)
        contentChanged(pageIndex: pageIndex)
    }

    // MARK: - Structural edits

    /// Applies a change to a page and records undo as a page snapshot (Memento).
    ///
    /// - Parameters:
    ///   - index: The page to change.
    ///   - actionName: Short description of the edit.
    ///   - mutate: The change.
    func updatePage(_ index: Int, actionName: String, _ mutate: (inout ZinePage) -> Void) {
        let before = zine.pages[index]
        var after = before
        mutate(&after)
        guard after != before else { return }
        setPage(after, at: index)
        history.record(actionName, pageIndex: index,
            undo: { [weak self] in self?.setPage(before, at: index) },
            redo: { [weak self] in self?.setPage(after, at: index) })
    }

    /// Applies a continuous change (slider, gesture) without recording undo.
    /// Call ``registerPageChange(_:from:actionName:)`` when the interaction ends.
    func updatePageLive(_ index: Int, _ mutate: (inout ZinePage) -> Void) {
        var page = zine.pages[index]
        mutate(&page)
        guard page != zine.pages[index] else { return }
        setPage(page, at: index)
    }

    /// Records a single undo step for a continuous change.
    ///
    /// - Parameters:
    ///   - index: The page that changed.
    ///   - before: The page as it was when the interaction started.
    ///   - actionName: Short description of the edit.
    func registerPageChange(_ index: Int, from before: ZinePage, actionName: String) {
        let after = zine.pages[index]
        guard after != before else { return }
        history.record(actionName, pageIndex: index,
            undo: { [weak self] in self?.setPage(before, at: index) },
            redo: { [weak self] in self?.setPage(after, at: index) })
    }

    private func setPage(_ page: ZinePage, at index: Int) {
        zine.pages[index] = page
        contentChanged(pageIndex: index)
    }

    /// Renames the zine. Empty titles are ignored.
    func rename(to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != zine.title else { return }
        zine.title = trimmed
        zine.modifiedAt = Date()
        scheduleSave()
    }

    // MARK: - Change tracking

    private func contentChanged(pageIndex: Int) {
        contentRevision += 1
        zine.modifiedAt = Date()
        staleThumbnails.insert(zine.pages[pageIndex].id)
        scheduleThumbnails()
        scheduleSave()
    }

    private func scheduleThumbnails(delay: Double = 0.6) {
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            self?.renderStaleThumbnails()
        }
    }

    private func renderStaleThumbnails() {
        for page in zine.pages where staleThumbnails.contains(page.id) {
            pageThumbnails[page.id] = PageRenderer.render(page: page, in: self, scale: 0.22)
        }
        staleThumbnails.removeAll()
    }

    // MARK: - Saving

    /// Saves 1.5 s after the latest change (debounced autosave).
    func scheduleSave() {
        needsSave = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Writes any pending change immediately. Safe to call repeatedly.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard needsSave else { return }
        needsSave = false
        do {
            try package.writeManifest(zine)

            var liveDrawingIDs = Set<UUID>()
            for page in zine.pages {
                for layer in page.layers where layer.isDrawing {
                    liveDrawingIDs.insert(layer.id)
                    let fileExists = FileManager.default.fileExists(atPath: package.drawingURL(for: layer.id).path)
                    // Also rewrites layers restored by undo after a previous save.
                    if dirtyDrawings.contains(layer.id) || !fileExists {
                        try package.writeDrawingData(drawing(for: layer.id).dataRepresentation(), for: layer.id)
                    }
                }
            }
            dirtyDrawings.removeAll()
            package.removeOrphanDrawings(keeping: liveDrawingIDs)

            let cover = PageRenderer.render(page: zine.pages[0], in: self, scale: 0.4)
            if let data = cover.jpegData(compressionQuality: 0.85) {
                try package.writeThumbnail(data)
            }
            lastSaveError = nil
        } catch {
            needsSave = true
            lastSaveError = "Falha ao salvar: \(error.localizedDescription)"
        }
    }
}
