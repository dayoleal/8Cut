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
    
    init(data: EditorData, size: CGSize) {
        self._data = .init(initialValue: data)
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if let controller = data.controller {
                PaperControllerView(controller: controller)
                    .shadow(radius: 10)
                    .frame(width: 800, height: 548)
                
                GridView()
                    .frame(width: size.width, height: size.height)
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
