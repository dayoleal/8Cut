//
//  ZineDocument.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import PencilKit
import Observation

/// Errors raised while editing a document.
enum ZineDocumentError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed: return "Não foi possível salvar a imagem."
        }
    }
}

/// An open zine. Keeps the manifest, drawings and images in memory, the edit
/// history, and saves changes to its ``ZinePackage``.
@MainActor
@Observable
final class ZineDocument {
    /// Package on disk.
    let package: ZinePackage
    /// Current manifest.
    private(set) var zine: Zine
    /// Undo/redo stack of this session.
    let history = EditHistory()

    /// Incremented on every content change.
    private(set) var contentRevision = 0
    /// Page thumbnails by page ID.
    private(set) var pageThumbnails: [UUID: UIImage] = [:]
    /// Last error raised while saving, if any.
    private(set) var lastSaveError: String?

    /// Called when undo/redo changes the drawing of a layer.
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

    /// Drawing of a layer, empty if it has none.
    func drawing(for layerID: UUID) -> PKDrawing {
        drawings[layerID] ?? PKDrawing()
    }

    /// Incremented when the drawing of the layer changes.
    func drawingRevision(for layerID: UUID) -> Int {
        drawingRevisions[layerID] ?? 0
    }

    /// Imported image, loaded from the package on first use.
    func image(named name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let image = UIImage(contentsOfFile: package.assetURL(named: name).path) else { return nil }
        images[name] = image
        return image
    }

    /// Page rendered at 700 px wide for the reader. Cached per revision.
    func readerImage(for index: Int) -> UIImage {
        if let cached = readerImages[index], cached.revision == contentRevision {
            return cached.image
        }
        let image = PageRenderer.render(page: zine.pages[index], in: self, scale: 0.7)
        readerImages[index] = (contentRevision, image)
        return image
    }

    /// All pages rendered at 1500 px wide for sharing.
    func shareImages() -> [UIImage] {
        zine.pages.map { PageRenderer.render(page: $0, in: self, scale: 1.5) }
    }

    // MARK: - Drawing edits

    /// Stores the drawing after a stroke and adds an undo entry.
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

    // MARK: - Images

    /// Saves an image in the package and adds it as a new layer on top of the page.
    ///
    /// The image is resized to at most 2400 px and placed in the center, filling
    /// 60% of the page.
    /// - Returns: ID of the new layer.
    @discardableResult
    func addImageLayer(_ image: UIImage, toPage index: Int) throws -> UUID {
        let hasAlpha = Self.hasAlpha(image)
        let prepared = Self.resized(image, maxDimension: 2400, opaque: !hasAlpha)
        let data = hasAlpha ? prepared.pngData() : prepared.jpegData(compressionQuality: 0.9)
        guard let data else { throw ZineDocumentError.imageEncodingFailed }

        let name = "\(UUID().uuidString).\(hasAlpha ? "png" : "jpg")"
        try package.writeAsset(data, named: name)
        images[name] = prepared

        let page = ZineFormat.pageSize
        let size = prepared.size
        let fit = min(page.width * 0.6 / size.width, page.height * 0.6 / size.height)
        let content = ImageLayerContent(
            assetName: name,
            width: size.width * fit,
            height: size.height * fit,
            transform: LayerTransform(centerX: page.width / 2, centerY: page.height / 2)
        )
        let imageCount = zine.pages[index].layers.filter { !$0.isDrawing }.count
        let layer = ZineLayer(id: UUID(), name: "Imagem \(imageCount + 1)", content: .image(content))
        updatePage(index, actionName: "Adicionar imagem") { $0.layers.append(layer) }
        return layer.id
    }

    /// Copies the drawing of a layer to another layer ID, without an undo entry.
    func copyDrawing(from sourceID: UUID, to destinationID: UUID) {
        drawings[destinationID] = drawing(for: sourceID)
        drawingRevisions[destinationID, default: 0] += 1
        dirtyDrawings.insert(destinationID)
    }

    private static func hasAlpha(_ image: UIImage) -> Bool {
        guard let alpha = image.cgImage?.alphaInfo else { return false }
        return [.first, .last, .premultipliedFirst, .premultipliedLast].contains(alpha)
    }

    /// Redraws the image at scale 1, fixing its orientation and limiting its size.
    private static func resized(_ image: UIImage, maxDimension: CGFloat, opaque: Bool) -> UIImage {
        let size = image.size
        let factor = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // MARK: - Structural edits

    /// Changes a page and adds an undo entry with the previous page.
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

    /// Changes a page without an undo entry, for sliders and gestures.
    /// Call ``registerPageChange(_:from:actionName:)`` when the gesture ends.
    func updatePageLive(_ index: Int, _ mutate: (inout ZinePage) -> Void) {
        var page = zine.pages[index]
        mutate(&page)
        guard page != zine.pages[index] else { return }
        setPage(page, at: index)
    }

    /// Adds one undo entry for a change made with ``updatePageLive(_:_:)``.
    ///
    /// - Parameters:
    ///   - index: The page that changed.
    ///   - before: The page before the gesture started.
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

    /// Saves 1.5 s after the last change.
    func scheduleSave() {
        needsSave = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Saves pending changes now.
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
                    // Missing files happen when undo restores a deleted layer.
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
