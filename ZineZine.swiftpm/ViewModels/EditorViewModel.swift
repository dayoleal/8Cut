//
//  EditorViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import PencilKit
import PhotosUI
import SwiftUI
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

/// Active image layer shown on the canvas.
struct ActiveImageLayer {
    var image: UIImage
    var content: ImageLayerContent
    var opacity: CGFloat
    var isVisible: Bool
    var isEditable: Bool
}

/// Values applied to the canvas on each update.
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
    /// Set when the active layer is an image.
    var activeImage: ActiveImageLayer?
    /// Space taken by the toolbars over the canvas.
    var fitInsets: UIEdgeInsets
}

/// View model of the editor. Builds the canvas configuration and handles canvas
/// events, pages, layers, image import and undo/redo.
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
    /// Set by the view from `deviceScale`.
    var layoutScale: CGFloat = 1
    var isShowingLayers = false
    /// Photo picked in the photo picker. Imported as soon as it is set.
    var photoSelection: PhotosPickerItem? {
        didSet { importSelectedPhoto() }
    }
    var errorMessage: String?
    /// Layer being renamed in the layers panel.
    var renamingLayerID: UUID?
    var layerDraftName = ""

    /// Called when undo/redo changes the drawing of the active layer.
    @ObservationIgnored var onActiveDrawingReplaced: ((PKDrawing) -> Void)?
    @ObservationIgnored weak var router: EditorRouting?

    /// Active layer per page (page ID → layer ID).
    private var activeLayerByPage: [UUID: UUID] = [:]
    @ObservationIgnored private var didAutoSwitchToPencil = false
    @ObservationIgnored private var compositeCache: (key: CompositeKey, value: PageComposites)?
    /// Page before a slider or gesture started, for a single undo entry.
    @ObservationIgnored private var pageBeforeLiveChange: ZinePage?

    /// Cache key of the composites. Leaves out the active layer, so moving an
    /// image or drawing does not render the other layers again.
    private struct CompositeKey: Equatable {
        var otherLayers: [ZineLayer]
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
        tools.onToolPicked = { [weak self] in self?.activateDrawingLayer() }
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

    /// Layer that receives strokes. Defaults to the top drawing layer.
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

    /// Current canvas configuration.
    var canvasConfiguration: PageCanvasConfiguration {
        let page = currentPage
        let activeLayer = page.layers.first { $0.id == activeLayerID }
        var activeImage: ActiveImageLayer?
        if let activeLayer, case .image(let content) = activeLayer.content,
           let image = document.image(named: content.assetName) {
            activeImage = ActiveImageLayer(image: image,
                                           content: content,
                                           opacity: CGFloat(activeLayer.opacity),
                                           isVisible: activeLayer.isVisible,
                                           isEditable: !activeLayer.isLocked)
        }
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
            activeImage: activeImage,
            fitInsets: UIEdgeInsets(top: 130 * layoutScale,
                                    left: 32 * layoutScale,
                                    bottom: (isToolSheetExpanded ? 150 : 60) * layoutScale,
                                    right: rightInset * layoutScale)
        )
    }

    /// Space for the open drawer on the right.
    private var rightInset: CGFloat {
        if isShowingLayers { return 270 }
        if isPageDrawerOpen { return 96 }
        return 32
    }

    /// Renders the layers below and above the active one, cached until they change.
    private func composites(for page: ZinePage) -> PageComposites {
        let activeID = activeLayerID
        // Read so the view updates on stroke changes.
        _ = document.contentRevision
        let key = CompositeKey(
            otherLayers: page.layers.filter { $0.id != activeID },
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

    /// Opens or closes the pages drawer. Closes the layers drawer.
    func togglePageDrawer() {
        isPageDrawerOpen.toggle()
        if isPageDrawerOpen { isShowingLayers = false }
    }

    /// Collapses or expands the tool sheet from a drag on its grabber.
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

    /// Saves pending changes when the app goes to the background.
    func sceneDidLeaveForeground() {
        document.saveNow()
    }

    // MARK: Canvas events

    /// Called at the end of a stroke on the active layer.
    func canvasDidCommit(_ drawing: PKDrawing, layerID: UUID, pageIndex: Int) {
        document.commitDrawing(drawing, layerID: layerID, pageIndex: pageIndex)
    }

    /// Turns off finger drawing on the first Apple Pencil touch. Only once per
    /// session, so the user can turn it back on.
    func canvasDidDetectPencil() {
        guard !didAutoSwitchToPencil else { return }
        didAutoSwitchToPencil = true
        tools.allowsFingerDrawing = false
    }

    /// Apple Pencil double tap.
    func canvasDidReceivePencilDoubleTap() { tools.toggleEraser() }

    func canvasDidBeginImageTransform() {
        pageBeforeLiveChange = currentPage
    }

    func canvasDidChangeImageTransform(_ transform: LayerTransform) {
        guard let layerID = activeLayerID else { return }
        document.updatePageLive(pageIndex) { page in
            guard let index = page.layers.firstIndex(where: { $0.id == layerID }),
                  case .image(var content) = page.layers[index].content else { return }
            content.transform = transform
            page.layers[index].content = .image(content)
        }
    }

    func canvasDidEndImageTransform() {
        endLiveChange(actionName: "Mover imagem")
    }

    // MARK: Layers

    /// Layers of the current page, top layer first.
    var layers: [ZineLayer] { currentPage.layers.reversed() }

    var activeLayer: ZineLayer? {
        currentPage.layers.first { $0.id == activeLayerID }
    }

    func isActive(_ layer: ZineLayer) -> Bool { layer.id == activeLayerID }

    var canDeleteLayers: Bool { currentPage.layers.count > 1 }

    func canMoveUp(_ layer: ZineLayer) -> Bool {
        guard let index = layerIndex(layer.id) else { return false }
        return index < currentPage.layers.count - 1
    }

    func canMoveDown(_ layer: ZineLayer) -> Bool {
        guard let index = layerIndex(layer.id) else { return false }
        return index > 0
    }

    /// Opens or closes the layers drawer. Closes the pages drawer.
    func toggleLayersPanel() {
        isShowingLayers.toggle()
        if isShowingLayers { isPageDrawerOpen = false }
    }

    func selectLayer(_ id: UUID) {
        activeLayerByPage[currentPage.id] = id
    }

    /// Adds an empty drawing layer above the active one and selects it.
    func addDrawingLayer() {
        let count = currentPage.layers.filter(\.isDrawing).count
        let layer = ZineLayer.drawing(name: "Desenho \(count + 1)")
        let insertIndex = activeLayerID.flatMap { layerIndex($0) }.map { $0 + 1 } ?? currentPage.layers.count
        document.updatePage(pageIndex, actionName: "Nova camada") { $0.layers.insert(layer, at: insertIndex) }
        selectLayer(layer.id)
    }

    func duplicateLayer(_ id: UUID) {
        guard let index = layerIndex(id) else { return }
        var copy = currentPage.layers[index]
        copy.id = UUID()
        copy.name += " (cópia)"
        if copy.isDrawing { document.copyDrawing(from: id, to: copy.id) }
        document.updatePage(pageIndex, actionName: "Duplicar camada") { $0.layers.insert(copy, at: index + 1) }
        selectLayer(copy.id)
    }

    func deleteLayer(_ id: UUID) {
        guard canDeleteLayers, let index = layerIndex(id) else { return }
        document.updatePage(pageIndex, actionName: "Apagar camada") { $0.layers.remove(at: index) }
    }

    /// Moves a dragged layer to the position of the layer it was dropped on.
    /// - Parameters:
    ///   - draggedID: Layer being dragged.
    ///   - targetID: Layer under the drop.
    func moveLayer(_ draggedID: UUID, onto targetID: UUID) {
        guard draggedID != targetID,
              let from = layerIndex(draggedID),
              let to = layerIndex(targetID) else { return }
        document.updatePage(pageIndex, actionName: "Mover camada") { page in
            let layer = page.layers.remove(at: from)
            page.layers.insert(layer, at: to)
        }
    }

    /// Moves a layer one step towards the top.
    func moveLayerUp(_ id: UUID) { moveLayer(id, by: 1) }

    /// Moves a layer one step towards the bottom.
    func moveLayerDown(_ id: UUID) { moveLayer(id, by: -1) }

    func toggleVisibility(_ id: UUID) {
        updateLayer(id, actionName: "Visibilidade") { $0.isVisible.toggle() }
    }

    func toggleLock(_ id: UUID) {
        updateLayer(id, actionName: "Bloquear camada") { $0.isLocked.toggle() }
    }

    func setBlendMode(_ mode: LayerBlendMode) {
        guard let id = activeLayerID else { return }
        updateLayer(id, actionName: "Modo de mesclagem") { $0.blendMode = mode }
    }

    /// Opacity of the active layer, for the slider.
    var activeLayerOpacity: Double {
        get { activeLayer?.opacity ?? 1 }
        set {
            guard let id = activeLayerID else { return }
            if pageBeforeLiveChange == nil { pageBeforeLiveChange = currentPage }
            document.updatePageLive(pageIndex) { page in
                guard let index = page.layers.firstIndex(where: { $0.id == id }) else { return }
                page.layers[index].opacity = min(max(newValue, 0), 1)
            }
        }
    }

    /// Call when the opacity slider is released.
    func opacityEditingChanged(_ isEditing: Bool) {
        if !isEditing { endLiveChange(actionName: "Opacidade") }
    }

    func beginRenameLayer(_ id: UUID) {
        layerDraftName = currentPage.layers.first { $0.id == id }?.name ?? ""
        renamingLayerID = id
    }

    func commitRenameLayer() {
        defer { renamingLayerID = nil }
        let name = layerDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = renamingLayerID, !name.isEmpty else { return }
        updateLayer(id, actionName: "Renomear camada") { $0.name = name }
    }

    var isRenamingLayer: Bool {
        get { renamingLayerID != nil }
        set { if !newValue { renamingLayerID = nil } }
    }

    /// Small render of a single layer for the layers panel.
    func layerThumbnail(_ layer: ZineLayer) -> UIImage? {
        _ = document.contentRevision
        guard let index = layerIndex(layer.id) else { return nil }
        return PageRenderer.render(page: currentPage, in: document, scale: 0.06,
                                   includePaper: false, layerRange: index..<(index + 1))
    }

    /// Selects the top drawing layer when a drawing tool is picked while an image
    /// layer is active. Adds one if the page has no drawing layer.
    func activateDrawingLayer() {
        guard activeLayer?.isDrawing == false else { return }
        if let top = currentPage.layers.last(where: \.isDrawing) {
            selectLayer(top.id)
        } else {
            addDrawingLayer()
        }
    }

    // MARK: Images

    private func importSelectedPhoto() {
        guard let item = photoSelection else { return }
        Task {
            defer { photoSelection = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    errorMessage = "Não foi possível abrir a imagem."
                    return
                }
                addImage(image)
            } catch {
                errorMessage = "Não foi possível abrir a imagem: \(error.localizedDescription)"
            }
        }
    }

    /// Adds an image to the current page and selects it.
    func addImage(_ image: UIImage) {
        do {
            let id = try document.addImageLayer(image, toPage: pageIndex)
            selectLayer(id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    // MARK: Private

    private func layerIndex(_ id: UUID) -> Int? {
        currentPage.layers.firstIndex { $0.id == id }
    }

    private func moveLayer(_ id: UUID, by offset: Int) {
        guard let index = layerIndex(id) else { return }
        let target = index + offset
        guard currentPage.layers.indices.contains(target) else { return }
        document.updatePage(pageIndex, actionName: "Mover camada") { $0.layers.swapAt(index, target) }
    }

    private func updateLayer(_ id: UUID, actionName: String, _ change: @escaping (inout ZineLayer) -> Void) {
        document.updatePage(pageIndex, actionName: actionName) { page in
            guard let index = page.layers.firstIndex(where: { $0.id == id }) else { return }
            change(&page.layers[index])
        }
    }

    private func endLiveChange(actionName: String) {
        guard let before = pageBeforeLiveChange else { return }
        pageBeforeLiveChange = nil
        document.registerPageChange(pageIndex, from: before, actionName: actionName)
    }
}
