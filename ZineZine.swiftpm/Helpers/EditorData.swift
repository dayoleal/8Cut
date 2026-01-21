//
//  EditorData.swift
//  DrawingEditor
//
//  Created by Dayô Araújo on 08/01/26.
//

import SwiftUI
import PaperKit
import PencilKit
import CoreImage.CIFilterBuiltins

@available(iOS 26.0, *)
@Observable
@MainActor
class EditorData {
    /// PaperKit variables
    var controller: PaperMarkupViewController?
    var markup: PaperMarkup?
    
    /// PencilKit variables
    var canvasView = PKCanvasView()
    var selectedColor: UIColor = .black
    var selectedWidth: CGFloat = 5.0
    
    var isDrawingMode: Bool = true {
        didSet {
            canvasView.isUserInteractionEnabled = isDrawingMode
        }
    }
    
    private var ciContext = CIContext()
    private var markupHistory: [PaperMarkup] = []
    
    /// Initialization Method that creates an empty PaperKit
    /// rectangular canvas with a placeholder text and a CanvasView
    func initializeController(_ rect: CGRect, placeholder: String = "Create!") {
        let controller = PaperMarkupViewController(supportedFeatureSet: .latest)
        let markup = PaperMarkup(bounds: rect)
        
        /// CanvasView
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        
        if let existingController = self.controller {
            existingController.markup = markup
            self.markup = markup
        } else {
            self.controller = controller
            self.markup = markup
            self.controller?.markup = markup
            self.controller?.zoomRange = 0.8...1.5
        }
        
        if !placeholder.isEmpty {
            let text = NSAttributedString(string: placeholder, attributes: [
                .font: UIFont.systemFont(ofSize: 18)
            ])
            let centerRect = text.centerRect(in: rect)
            insertText(text, rect: centerRect)
        }
    }
    
    // MARK: - Custom PencilKit Tool Methods
    
    /// Method that applies the tool's shader
    func selectTool(_ inkType: PKInkingTool.InkType) {
        isDrawingMode = true
        canvasView.tool = PKInkingTool(inkType, color: selectedColor, width: selectedWidth)
    }
    
    /// Method that applies the PKEraserTool
    func selectEraser() {
        isDrawingMode = true
        canvasView.tool = PKEraserTool(.vector)
    }
    
    /// Method that updates the tool's selected color
    func updateColor(_ color: Color) {
        let uiColor = UIColor(color)
        self.selectedColor = uiColor
        
        if let currentInkingTool = canvasView.tool as? PKInkingTool {
            canvasView.tool = PKInkingTool(currentInkingTool.inkType, color: uiColor, width: selectedWidth)
        }
    }
    
    func enterObjectEditMode() {
        isDrawingMode = false
    }
    
    // MARK: - Editing Methods
    
    /// Method to insert editable text
    func insertText(_ text: NSAttributedString, rect: CGRect) {
        markup?.insertNewTextbox(attributedText: text, frame: rect)
        refreshController()
    }
    
    /// Method to insert images
    func insertImage(_ image: UIImage, rect: CGRect) {
        guard let cgImage = image.cgImage else { return }
        markup?.insertNewImage(cgImage, frame: rect)
        refreshController()
    }
    
    /// Method to insert Shapes
    func insertShape(_ type: ShapeConfiguration, rect: CGRect) {
        markup?.insertNewShape(configuration: type, frame: rect)
        refreshController()
    }
    
    /// Method to update the controller state based on modifications
    func refreshController() {
        controller?.markup = markup
    }
    
    /// Method to show pencil kit tools, such as pens and pencils
    func showPencilKitTools(_ isVisible: Bool) {
        canvasView.isUserInteractionEnabled = isVisible
    }
    
    /// Method to export the canvas as an Image
    func exportAsImage(_ rect: CGRect, scale: CGFloat = 1) async -> UIImage? {
        guard let context = makeCGContext(size: rect.size, scale: scale),
              let markup = await controller?.markup else { return nil }
        
        await markup.draw(in: context, frame: rect)
        
        // Adiciona o desenho do PencilKit por cima na exportação
        let drawingImage = canvasView.drawing.image(from: rect, scale: scale)
        context.draw(drawingImage.cgImage!, in: rect)
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Method to export the canvas as Data
    func exportAsData() async -> Data? {
        do {
            return try await markup?.dataRepresentation()
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    /// Method to apply filters to the canvas
    func applyFilterToCanvas(_ filter: CIFilter, rect: CGRect) async {
        guard let currentUIImage = await exportAsImage(rect, scale: 2),
              let ciImage = CIImage(image: currentUIImage) else { return }
        
        if let currentMarkup = self.markup {
            markupHistory.append(currentMarkup)
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        var filteredMarkup = PaperMarkup(bounds: rect)
        filteredMarkup.insertNewImage(cgImage, frame: rect)
        
        self.markup = filteredMarkup
        canvasView.drawing = PKDrawing()
        refreshController()
    }
    
    /// Reverts the filter applied by the user
    func revertFilters() {
        guard let previousState = markupHistory.popLast() else { return }
        self.markup = previousState
        refreshController()
    }
    
    /// CGContext creation
    private func makeCGContext(size: CGSize, scale: CGFloat) -> CGContext? {
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
        
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        
        return context
    }
}

/// Calculating the center of the giving rectangle
extension NSAttributedString {
    func centerRect(in rect: CGRect) -> CGRect {
        let textSize = self.size()
        let textCenter = CGPoint(
            x: rect.midX - (textSize.width / 2),
            y: rect.midY - (textSize.height / 2)
        )
        
        return CGRect(origin: textCenter, size: textSize)
    }
}
