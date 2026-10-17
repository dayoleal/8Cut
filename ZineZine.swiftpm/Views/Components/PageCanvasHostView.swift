//
//  PageCanvasHostView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass
import PencilKit

/// `PKCanvasView` with a private `UndoManager`.
final class ZineCanvasView: PKCanvasView {
    private let privateUndoManager = UndoManager()
    override var undoManager: UndoManager? { privateUndoManager }
}

/// UIKit canvas of a page. The active layer is a live `PKCanvasView`; the layers
/// below and above it are shown as rendered images.
final class PageCanvasHostView: UIView {
    /// Canvas of the active layer.
    let canvasView = ZineCanvasView()
    private let paperView = UIView()
    private let belowView = UIImageView()
    private let aboveView = UIImageView()
    /// Active image layer, moved with pan, pinch and rotation.
    private let imageLayerView = UIImageView()

    // MARK: Callbacks

    var onDrawingCommitted: ((PKDrawing) -> Void)?
    var onPencilDetected: (() -> Void)?
    var onPencilDoubleTap: (() -> Void)?
    var onUndoGesture: (() -> Void)?
    var onRedoGesture: (() -> Void)?
    var onImageTransformBegan: (() -> Void)?
    var onImageTransformChanged: ((LayerTransform) -> Void)?
    var onImageTransformEnded: (() -> Void)?

    // MARK: State

    private var lastDrawing = PKDrawing()
    private var isLoadingDrawing = false
    private var lastLayoutSize: CGSize = .zero
    private var fitZoomScale: CGFloat = 1
    private var imageContent: ImageLayerContent?
    private var activeImageGestures = 0

    /// Space taken by the toolbars. The page is fitted in the remaining area.
    var fitInsets: UIEdgeInsets = .zero {
        didSet {
            guard fitInsets != oldValue else { return }
            lastLayoutSize = .zero
            setNeedsLayout()
            UIView.animate(withDuration: 0.3) { self.layoutIfNeeded() }
        }
    }

    var paperColor: UIColor = .white {
        didSet { paperView.backgroundColor = paperColor }
    }

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        backgroundColor = .clear
        clipsToBounds = true

        paperView.backgroundColor = paperColor
        paperView.isUserInteractionEnabled = false
        paperView.layer.shadowColor = UIColor.black.cgColor
        paperView.layer.shadowOpacity = 0.35
        paperView.layer.shadowRadius = 18
        paperView.layer.shadowOffset = CGSize(width: 0, height: 10)

        for overlay in [belowView, aboveView] {
            overlay.contentMode = .scaleToFill
            overlay.isUserInteractionEnabled = false
        }

        imageLayerView.contentMode = .scaleToFill
        imageLayerView.isUserInteractionEnabled = true
        imageLayerView.isHidden = true
        imageLayerView.layer.borderColor = UIColor(named: "acidGreen")?.cgColor

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.overrideUserInterfaceStyle = .light
        canvasView.contentInsetAdjustmentBehavior = .never
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.bouncesZoom = true
        canvasView.delegate = self

        addSubview(paperView)
        addSubview(belowView)
        addSubview(canvasView)
        addSubview(imageLayerView)
        addSubview(aboveView)

        installGestures()
    }

    private func installGestures() {
        // Two-finger tap undoes, three-finger tap redoes.
        let undoTap = UITapGestureRecognizer(target: self, action: #selector(handleUndoTap))
        undoTap.numberOfTouchesRequired = 2
        undoTap.delegate = self
        addGestureRecognizer(undoTap)

        let redoTap = UITapGestureRecognizer(target: self, action: #selector(handleRedoTap))
        redoTap.numberOfTouchesRequired = 3
        redoTap.delegate = self
        addGestureRecognizer(redoTap)

        let pencilDetector = PencilTouchDetector(target: nil, action: nil)
        pencilDetector.cancelsTouchesInView = false
        pencilDetector.delaysTouchesBegan = false
        pencilDetector.delaysTouchesEnded = false
        pencilDetector.onPencil = { [weak self] in self?.onPencilDetected?() }
        pencilDetector.delegate = self
        addGestureRecognizer(pencilDetector)

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleImagePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleImagePinch(_:)))
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleImageRotation(_:)))
        for gesture in [pan, pinch, rotation] as [UIGestureRecognizer] {
            gesture.delegate = self
            imageLayerView.addGestureRecognizer(gesture)
        }
    }

    // MARK: - Layout & zoom

    override func layoutSubviews() {
        super.layoutSubviews()
        canvasView.frame = bounds
        if bounds.size != lastLayoutSize, bounds.width > 0, bounds.height > 0 {
            lastLayoutSize = bounds.size
            fitToScreen(animated: false)
        }
        syncOverlays()
    }

    /// Zooms to fit the page in the free area and centers it.
    ///
    /// - Parameter animated: Whether to animate the change.
    func fitToScreen(animated: Bool) {
        let page = ZineFormat.pageSize
        let margin: CGFloat = 16
        let available = bounds.inset(by: fitInsets)
        let fit = min((available.width - margin * 2) / page.width,
                      (available.height - margin * 2) / page.height)
        guard fit > 0 else { return }
        fitZoomScale = fit
        canvasView.minimumZoomScale = fit * 0.6
        canvasView.maximumZoomScale = fit * 8
        canvasView.setZoomScale(fit, animated: animated)
        canvasView.contentSize = CGSize(width: page.width * fit, height: page.height * fit)
        centerContent()
        // Content is smaller than the free area, so the offset is the inset.
        canvasView.setContentOffset(CGPoint(x: -canvasView.contentInset.left,
                                            y: -canvasView.contentInset.top),
                                    animated: animated)
        syncOverlays()
    }

    private func centerContent() {
        let page = ZineFormat.pageSize
        let zoom = canvasView.zoomScale
        let available = bounds.inset(by: fitInsets)
        let insetX = max((available.width - page.width * zoom) / 2, 0)
        let insetY = max((available.height - page.height * zoom) / 2, 0)
        canvasView.contentInset = UIEdgeInsets(top: fitInsets.top + insetY,
                                               left: fitInsets.left + insetX,
                                               bottom: fitInsets.bottom + insetY,
                                               right: fitInsets.right + insetX)
    }

    /// Moves the paper and rendered layers to the page position in the canvas.
    private func syncOverlays() {
        let page = ZineFormat.pageSize
        let zoom = canvasView.zoomScale
        let frame = CGRect(x: -canvasView.contentOffset.x,
                           y: -canvasView.contentOffset.y,
                           width: page.width * zoom,
                           height: page.height * zoom)
        paperView.frame = frame
        belowView.frame = frame
        aboveView.frame = frame
        paperView.layer.shadowPath = UIBezierPath(rect: paperView.bounds).cgPath
        layoutImageLayer()
    }

    /// Places the active image using its transform in page coordinates.
    private func layoutImageLayer() {
        guard let content = imageContent else { return }
        let zoom = canvasView.zoomScale
        let transform = content.transform
        imageLayerView.transform = .identity
        imageLayerView.bounds = CGRect(x: 0, y: 0, width: content.width * zoom, height: content.height * zoom)
        imageLayerView.center = CGPoint(x: -canvasView.contentOffset.x + transform.centerX * zoom,
                                        y: -canvasView.contentOffset.y + transform.centerY * zoom)
        imageLayerView.transform = CGAffineTransform(rotationAngle: transform.rotation)
            .scaledBy(x: transform.scale, y: transform.scale)
        imageLayerView.layer.borderWidth = 2 / max(transform.scale, 0.01)
    }

    // MARK: - Content

    /// Sets the drawing without creating an edit.
    func load(drawing: PKDrawing) {
        isLoadingDrawing = true
        canvasView.drawing = drawing
        lastDrawing = drawing
        isLoadingDrawing = false
        canvasView.undoManager?.removeAllActions()
    }

    /// Sets the rendered layers below and above the active one.
    func setComposites(below: UIImage?, above: UIImage?) {
        belowView.image = below
        aboveView.image = above
    }

    /// Applies visibility, opacity and lock of the active layer.
    func configureActiveLayer(isVisible: Bool, opacity: CGFloat, isEditable: Bool) {
        canvasView.alpha = isVisible ? opacity : 0
        canvasView.drawingGestureRecognizer.isEnabled = isEditable && isVisible
    }

    /// Shows the active image layer, or hides it when `image` is `nil`.
    func setActiveImage(_ image: UIImage?, content: ImageLayerContent?,
                        opacity: CGFloat, isVisible: Bool, isEditable: Bool) {
        imageLayerView.image = image
        imageLayerView.isHidden = image == nil || !isVisible
        imageLayerView.alpha = opacity
        imageLayerView.isUserInteractionEnabled = isEditable
        // The gesture already moved the view; don't reset it mid-gesture.
        if activeImageGestures == 0 {
            imageContent = content
            layoutImageLayer()
        }
    }

    // MARK: - Actions

    @objc private func handleUndoTap() { onUndoGesture?() }
    @objc private func handleRedoTap() { onRedoGesture?() }

    @objc private func handleImagePan(_ gesture: UIPanGestureRecognizer) {
        updateImage(with: gesture) { transform, zoom in
            let translation = gesture.translation(in: self)
            transform.centerX += translation.x / zoom
            transform.centerY += translation.y / zoom
            gesture.setTranslation(.zero, in: self)
        }
    }

    @objc private func handleImagePinch(_ gesture: UIPinchGestureRecognizer) {
        updateImage(with: gesture) { transform, _ in
            transform.scale = min(max(transform.scale * gesture.scale, 0.05), 20)
            gesture.scale = 1
        }
    }

    @objc private func handleImageRotation(_ gesture: UIRotationGestureRecognizer) {
        updateImage(with: gesture) { transform, _ in
            transform.rotation += gesture.rotation
            gesture.rotation = 0
        }
    }

    /// Applies a gesture to the image transform and reports begin, change and end.
    /// Pan, pinch and rotation can run together; begin/end are sent once.
    private func updateImage(with gesture: UIGestureRecognizer,
                             change: (inout LayerTransform, CGFloat) -> Void) {
        guard var content = imageContent else { return }
        switch gesture.state {
        case .began:
            if activeImageGestures == 0 { onImageTransformBegan?() }
            activeImageGestures += 1
        case .ended, .cancelled, .failed:
            activeImageGestures = max(activeImageGestures - 1, 0)
            if activeImageGestures == 0 { onImageTransformEnded?() }
            return
        default:
            break
        }
        change(&content.transform, canvasView.zoomScale)
        imageContent = content
        layoutImageLayer()
        onImageTransformChanged?(content.transform)
    }
}

// MARK: - PKCanvasViewDelegate

extension PageCanvasHostView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isLoadingDrawing else { return }
        let drawing = canvasView.drawing
        guard drawing != lastDrawing else { return }
        lastDrawing = drawing
        canvasView.undoManager?.removeAllActions()
        onDrawingCommitted?(drawing)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncOverlays()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        syncOverlays()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // Zooming out below the fitted size returns to the fitted size.
        if scale < fitZoomScale {
            fitToScreen(animated: true)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PageCanvasHostView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

// MARK: - UIPencilInteractionDelegate

extension PageCanvasHostView: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch UIPencilInteraction.preferredTapAction {
        case .ignore, .showColorPalette:
            return
        default:
            onPencilDoubleTap?()
        }
    }
}

// MARK: - PencilTouchDetector

/// Gesture recognizer that never recognizes. Reports Apple Pencil touches.
final class PencilTouchDetector: UIGestureRecognizer {
    var onPencil: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touches.contains(where: { $0.type == .pencil }) {
            onPencil?()
        }
        state = .failed
    }
}

// MARK: - Previews

#Preview("UIKit canvas", traits: .landscapeLeft) {
    PreviewData.canvasHostView()
}
