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
    }
}

@available(iOS 26.0, *)
/// Paper controller view
fileprivate struct PaperControllerView: UIViewControllerRepresentable {
    var controller: PaperMarkupViewController
    var backgroundColor: UIColor = .lightGray
    
    func makeUIViewController(context: Context) -> PaperMarkupViewController {
        controller.view.backgroundColor = backgroundColor
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PaperMarkupViewController, context: Context) {
        controller.view.backgroundColor = backgroundColor
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        ContentView()
    } else {
        
    }
}
