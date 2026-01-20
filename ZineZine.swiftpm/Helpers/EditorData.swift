//
//  EditorData.swift
//  DrawingEditor
//
//  Created by Dayô Araújo on 08/01/26.
//

import SwiftUI
import PaperKit
import PencilKit

@available(iOS 26.0, *)
@Observable
@MainActor
class EditorData: NSObject, PKToolPickerObserver {
    var controller: PaperMarkupViewController?
    var markup: PaperMarkup?
    private var toolBehaviors: [String: PKTool] = [:]
    
    /// Initialization Method that creates an empty PaperKit rectangular canvas with a placeholder text
    func initializeController(_ rect: CGRect, placeholder: String = "Create!") {
        let controller = PaperMarkupViewController(supportedFeatureSet: .latest)
        let markup = PaperMarkup(bounds: rect)
        
        /// Ensures that the canvas begins with an empty state whenever the method
        /// `initializeController` is invoked
        if let existingController = self.controller {
            existingController.markup = markup
            self.markup = markup
        } else {
            self.controller = controller
            self.markup = markup
            self.controller?.markup = markup
            self.controller?.zoomRange = 0.8...1.5
        }
        
        /// Adding the text to the center of the canvas
        if !placeholder.isEmpty {
            let text = NSAttributedString(string: placeholder, attributes: [
                .font: UIFont.systemFont(ofSize: 18)
            ])
            
            let centerRect = text.centerRect(in: rect)
            insertText(text, rect: centerRect)
        }
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
    /// and create custom tools with system shader behaviours
    func showPencilKitTools(_ isVisible: Bool) {
        guard let controller else { return }
        
        /// Tool Configurations that conform to the
        ///  PKToolPickerCustomItem.Configuration and shader type
        let toolDefinitions: [(id: String, name: String, tool: PKTool)] = [
            ("spherographic.tool", "spherographic", PKInkingTool(.pen, color: .black)),
            ("nanquin.tool", "nanquin", PKInkingTool(.monoline, color: .black)),
            ("highlighter.tool", "highlighter", PKInkingTool(.marker, color: .yellow)),
            ("eraser.tool", "eraser", PKEraserTool(.vector)),
            ("pencil.tool", "pencil", PKInkingTool(.pencil, color: .black)),
            ("crayon.tool", "crayon", PKInkingTool(.crayon, color: .black)),
            ("pen.tool", "pen", PKInkingTool(.fountainPen, color: .black)),
            ("brush.tool", "brush", PKInkingTool(.reed, color: .black))
        ]
        
        var customItems: [PKToolPickerCustomItem] = []
        
        /// Configurations being applied to ensure the creation of
        ///  each tool item
        for index in toolDefinitions {
            var config = PKToolPickerCustomItem.Configuration(identifier: index.id, name: index.name)
            
            config.imageProvider = { _ in
                UIImage(named: index.name) ?? UIImage(systemName: "pencil.tip")!
            }
            
            let item = PKToolPickerCustomItem(configuration: config)
            customItems.append(item)
            
            toolBehaviors[index.id] = index.tool
        }
        
        let picker = PKToolPicker(toolItems: customItems)
        picker.overrideUserInterfaceStyle = .dark
        
        picker.addObserver(self)
        
        controller.view.pencilKitResponderState.activeToolPicker = picker
        controller.view.pencilKitResponderState.toolPickerVisibility = isVisible ? .visible : .hidden
        
        if isVisible {
            controller.view.becomeFirstResponder()
        }
    }
    
    /// Method to export the canvas as an Image
    func exportAsImage(_ rect: CGRect, scale: CGFloat = 1) async -> UIImage? {
        guard let context = makeCGContext(size: rect.size, scale: scale),
              let markup = await controller?.markup else { return nil }
        
        await markup.draw(in: context, frame: rect)
        guard let cgImage = context.makeImage() else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Method to apply filters to the canvas
    
    
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

/// Extension that identifies the tool that is selected and applies
/// the appropriate shader based on the `toolBehaviours` dictionary
@available(iOS 26.0, *)
extension EditorData: PKToolPickerObserver {
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        guard let controller = self.controller else { return }
        
        /// Storing the item selected by the user as a custom item
        /// and getting the id of said tool in order to map the
        /// shader behaviour
        let customItem = toolPicker.selectedToolItem as! PKToolPickerCustomItem
        let id = customItem.configuration.identifier
        
        let baseTool = toolBehaviors[id]
        var finalTool: PKTool = baseTool!
        
        /// Guarantees that the tool behaviour is similar to a
        ///  PKInkingTool
        if let inkingTool = baseTool as? PKInkingTool {
            finalTool = PKInkingTool(
                inkingTool.inkType,
                color: .black,
                width: inkingTool.width
            )
        }
        
        /// Applying the shader behaviour to the active tool
        controller.view.pencilKitResponderState.activeToolPicker?.selectedToolItem = customItem
        
        /// Identifying the canvas to which the shader must be applied
        for index in controller.view.subviews {
            if let canvas = index as? PKCanvasView {
                canvas.tool = finalTool
                break
            }
        }
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
