//
//  EditorView.swift
//  DrawingEditor
//
//  Created by Dayô Araújo on 08/01/26.
//
import SwiftUI
import PaperKit
import PencilKit

@available(iOS 26.0, *)
struct EditorView: View {
    @State var data: EditorData
    var size: CGSize
    
    var body: some View {
        ZStack {
            if let controller = data.controller {
                /// PaperKit layer that controls images, shapes and text
                PaperControllerView(controller: controller)
                    .frame(width: size.width, height: size.height)
                
                /// PencilKit layer that controls drawings
                CanvasRepresentable(canvasView: data.canvasView)
                    .frame(width: size.width, height: size.height)
                
                GridView()
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            } else {
                ProgressView()
                    .onAppear {
                        data.initializeController(.init(origin: .zero, size: size))
                    }
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("background")
                .resizable()
                .scaledToFill()
        )
    }
}

@available(iOS 26.0, *)
/// Paper controller view
fileprivate struct PaperControllerView: UIViewControllerRepresentable {
    var controller: PaperMarkupViewController
    
    func makeUIViewController(context: Context) -> PaperMarkupViewController {
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PaperMarkupViewController, context: Context) {
    }
}

@available(iOS 26.0, *)
#Preview (traits: .landscapeLeft){
    ContentView()
}
