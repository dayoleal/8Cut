//
//  EditorViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import PencilKit
import Observation

/// Navigation requested by the editor (implemented by ``AppViewModel``).
@MainActor
protocol EditorRouting: AnyObject {
    func closeEditor(saving document: ZineDocument)
}

/// Flattened layers below and above the active one.
struct PageComposites {
    var below: UIImage?
    var above: UIImage?
}

/// Everything the canvas renders, as one value produced by ``EditorViewModel``.
struct PageCanvasConfiguration {
    var pageIndex: Int
    var activeLayerID: UUID?
    var tool: ToolConfiguration
    var isRulerActive: Bool
    var allowsFingerDrawing: Bool
    var paperColor: UIColor
    var isActiveLayerVisible: Bool
    var activeLayerOpacity: CGFloat
    var isActiveLayerEditable: Bool
    var composites: PageComposites
    /// Space covered by the floating chrome.
    var fitInsets: UIEdgeInsets
}

/// State and actions of the editor screen.
///
/// Decides what the canvas shows (``canvasConfiguration``), receives every
/// canvas event (stroke committed, Pencil detected, undo gestures) and drives
/// the chrome. ``EditorView`` and its components only render.
@MainActor
@Observable
final class EditorViewModel {
    /// The zine being edited.
    let document: ZineDocument
    /// Tool tray state.
    let tools: ToolPaletteViewModel

    /// Page shown on the canvas.
    var pageIndex = 0
    var isToolSheetExpanded = true
    var isPageDrawerOpen = false
    var shareItems: ShareItems?
    /// Size factor of the chrome, set by the view from `deviceScale`.
    var layoutScale: CGFloat = 1

    /// Called when undo/redo replaces the strokes of the layer on the canvas.
    @ObservationIgnored var onActiveDrawingReplaced: ((PKDrawing) -> Void)?
    @ObservationIgnored weak var router: EditorRouting?

    /// Active layer per page (page ID → layer ID).
    private var activeLayerByPage: [UUID: UUID] = [:]
    @ObservationIgnored private var didAutoSwitchToPencil = false
    @ObservationIgnored private var compositeCache: (key: CompositeKey, value: PageComposites)?

    /// Everything the composites depend on.
    private struct CompositeKey: Equatable {
        var page: ZinePage
        var activeLayerID: UUID?
        var otherDrawingRevisions: [Int]
    }

    init(document: ZineDocument,
         tools: ToolPaletteViewModel = ToolPaletteViewModel(),
         router: EditorRouting? = nil) {
        self.document = document
        self.tools = tools
        self.router = router
        document.onDrawingReplaced = { [weak self] layerID in
            guard let self, layerID == self.activeLayerID else { return }
            self.onActiveDrawingReplaced?(self.document.drawing(for: layerID))
        }
    }

    // MARK: Pages

    var pages: [ZinePage] { document.pages }
    var currentPage: ZinePage { document.page(at: pageIndex) }

    func thumbnail(for page: ZinePage) -> UIImage? { document.pageThumbnails[page.id] }
    func label(forPage index: Int) -> String { ZineFormat.pageLabel(index) }
    func isSelected(page index: Int) -> Bool { index == pageIndex }

    // MARK: History

    var canUndo: Bool { document.history.canUndo }
    var canRedo: Bool { document.history.canRedo }

    // MARK: Canvas

    /// The layer receiving strokes: the user's choice, else the top drawing layer.
    var activeLayerID: UUID? {
        let page = currentPage
        if let chosen = activeLayerByPage[page.id], page.layers.contains(where: { $0.id == chosen }) {
            return chosen
        }
        return page.layers.last(where: \.isDrawing)?.id ?? page.layers.last?.id
    }

    /// Strokes of the active layer.
    var activeDrawing: PKDrawing {
        activeLayerID.map { document.drawing(for: $0) } ?? PKDrawing()
    }

    /// Everything the canvas needs to render the current state.
    var canvasConfiguration: PageCanvasConfiguration {
        let page = currentPage
        let activeLayer = page.layers.first { $0.id == activeLayerID }
        return PageCanvasConfiguration(
            pageIndex: pageIndex,
            activeLayerID: activeLayerID,
            tool: tools.configuration,
            isRulerActive: tools.isRulerActive,
            allowsFingerDrawing: tools.allowsFingerDrawing,
            paperColor: page.paperColor.uiColor,
            isActiveLayerVisible: activeLayer?.isVisible ?? false,
            activeLayerOpacity: CGFloat(activeLayer?.opacity ?? 1),
            isActiveLayerEditable: (activeLayer?.isDrawing ?? false) && !(activeLayer?.isLocked ?? true),
            composites: composites(for: page),
            fitInsets: UIEdgeInsets(top: 130 * layoutScale,
                                    left: 32 * layoutScale,
                                    bottom: (isToolSheetExpanded ? 150 : 60) * layoutScale,
                                    right: (isPageDrawerOpen ? 96 : 32) * layoutScale)
        )
    }

    /// Flattens the layers around the active one, re-rendering only when they change.
    private func composites(for page: ZinePage) -> PageComposites {
        let activeID = activeLayerID
        // Reading the revision registers observation of stroke changes.
        _ = document.contentRevision
        let key = CompositeKey(
            page: page,
            activeLayerID: activeID,
            otherDrawingRevisions: page.layers
                .filter { $0.id != activeID }
                .map { document.drawingRevision(for: $0.id) }
        )
        if let cache = compositeCache, cache.key == key { return cache.value }

        let scale: CGFloat = 1.5
        let value: PageComposites
        if let activeIndex = page.layers.firstIndex(where: { $0.id == activeID }) {
            value = PageComposites(
                below: activeIndex > 0
                    ? PageRenderer.render(page: page, in: document, scale: scale,
                                          includePaper: false, layerRange: 0..<activeIndex)
                    : nil,
                above: activeIndex < page.layers.count - 1
                    ? PageRenderer.render(page: page, in: document, scale: scale,
                                          includePaper: false, layerRange: (activeIndex + 1)..<page.layers.count)
                    : nil
            )
        } else {
            value = PageComposites(below: PageRenderer.render(page: page, in: document, scale: scale,
                                                              includePaper: false),
                                   above: nil)
        }
        compositeCache = (key, value)
        return value
    }

    // MARK: Actions

    func selectPage(_ index: Int) {
        guard document.pages.indices.contains(index) else { return }
        pageIndex = index
    }

    func goToPreviousPage() { selectPage(pageIndex - 1) }
    func goToNextPage() { selectPage(pageIndex + 1) }

    /// Undoes the latest edit and shows the page it happened on.
    func undo() {
        if let page = document.history.undo() { pageIndex = page }
    }

    /// Redoes the latest undone edit and shows the page it happened on.
    func redo() {
        if let page = document.history.redo() { pageIndex = page }
    }

    func toggleToolSheet() { isToolSheetExpanded.toggle() }
    func togglePageDrawer() { isPageDrawerOpen.toggle() }

    /// Collapses or expands the tool sheet from a vertical drag on its grabber.
    ///
    /// - Parameter translation: Vertical drag distance; positive is downwards.
    func handleToolSheetDrag(translation: CGFloat) {
        if translation > 30, isToolSheetExpanded { isToolSheetExpanded = false }
        if translation < -30, !isToolSheetExpanded { isToolSheetExpanded = true }
    }

    func share() {
        document.saveNow()
        shareItems = ShareItems(images: document.shareImages())
    }

    func close() {
        router?.closeEditor(saving: document)
    }

    /// Persists pending changes when the app leaves the foreground.
    func sceneDidLeaveForeground() {
        document.saveNow()
    }

    // MARK: Canvas events

    /// A stroke (or erase) finished on the active layer.
    func canvasDidCommit(_ drawing: PKDrawing, layerID: UUID, pageIndex: Int) {
        document.commitDrawing(drawing, layerID: layerID, pageIndex: pageIndex)
    }

    /// First Apple Pencil touch: fingers switch to navigation. Happens once, so
    /// turning finger drawing back on is respected.
    func canvasDidDetectPencil() {
        guard !didAutoSwitchToPencil else { return }
        didAutoSwitchToPencil = true
        tools.allowsFingerDrawing = false
    }

    /// Apple Pencil double tap.
    func canvasDidReceivePencilDoubleTap() { tools.toggleEraser() }
}
