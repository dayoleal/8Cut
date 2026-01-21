//
//  CanvasRepresentable.swift
//  ZineZine
//
//  Created by Dayô Araújo on 20/01/26.
//

import SwiftUI
import PencilKit

struct CanvasRepresentable: UIViewRepresentable {
    var canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) { }
}
