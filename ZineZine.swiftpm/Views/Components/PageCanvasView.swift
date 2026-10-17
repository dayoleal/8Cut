//
//  PageCanvasView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI
import PencilKit

/// SwiftUI bridge to ``PageCanvasHostView``.
struct PageCanvasView: UIViewRepresentable {
    let viewModel: EditorViewModel

    /// Remembers what is already applied to avoid redundant work.
    final class Coordinator {
        var pageIndex: Int?
        var layerID: UUID?
        var tool: ToolConfiguration?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PageCanvasHostView {
        let view = PageCanvasHostView()
        let viewModel = viewModel
        let coordinator = context.coordinator

        viewModel.onActiveDrawingReplaced = { [weak view] drawing in view?.load(drawing: drawing) }
        view.onPencilDetected = { [weak viewModel] in viewModel?.canvasDidDetectPencil() }
        view.onPencilDoubleTap = { [weak viewModel] in viewModel?.canvasDidReceivePencilDoubleTap() }
        view.onUndoGesture = { [weak viewModel] in viewModel?.undo() }
        view.onRedoGesture = { [weak viewModel] in viewModel?.redo() }
        view.onDrawingCommitted = { [weak viewModel] drawing in
            guard let layerID = coordinator.layerID, let pageIndex = coordinator.pageIndex else { return }
            viewModel?.canvasDidCommit(drawing, layerID: layerID, pageIndex: pageIndex)
        }
        return view
    }

    func updateUIView(_ view: PageCanvasHostView, context: Context) {
        let coordinator = context.coordinator
        let configuration = viewModel.canvasConfiguration

        if coordinator.pageIndex != configuration.pageIndex || coordinator.layerID != configuration.activeLayerID {
            coordinator.pageIndex = configuration.pageIndex
            coordinator.layerID = configuration.activeLayerID
            view.load(drawing: viewModel.activeDrawing)
        }

        if coordinator.tool != configuration.tool {
            coordinator.tool = configuration.tool
            view.canvasView.tool = configuration.tool.makePKTool()
        }
        if view.canvasView.isRulerActive != configuration.isRulerActive {
            view.canvasView.isRulerActive = configuration.isRulerActive
        }
        view.canvasView.drawingPolicy = configuration.allowsFingerDrawing ? .anyInput : .pencilOnly
        view.paperColor = configuration.paperColor
        view.fitInsets = configuration.fitInsets
        view.configureActiveLayer(isVisible: configuration.isActiveLayerVisible,
                                  opacity: configuration.activeLayerOpacity,
                                  isEditable: configuration.isActiveLayerEditable)
        view.setComposites(below: configuration.composites.below, above: configuration.composites.above)
    }
}

// MARK: - Previews

#Preview(traits: .landscapeLeft) {
    PageCanvasView(viewModel: PreviewData.editorViewModel())
        .background(Color.chromeDark)
}
