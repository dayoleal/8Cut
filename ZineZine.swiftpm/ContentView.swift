//
//  ContentView.swift
//  DrawingEditor
//
//  Created by Dayô Araújo on 08/01/26.
//

import SwiftUI
import PaperKit
import PhotosUI

@available(iOS 26.0, *)
struct ContentView: View {
    @State private var data = EditorData()
    @State private var showTools: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var photoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            EditorView(data: data, size: .init(width: 356, height: 504))
                .toolbar {
                    toolItems()
                }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $photoItem)
        .onChange(of: photoItem) { oldValue, newValue in
            guard let newValue else { return }
            Task {
                guard let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    return
                }
                
                self.data.insertImage(image, rect: .init(origin: .zero, size: .init(width: 100, height: 100)))
                photoItem = nil
            }
        }
    }
    
    @ViewBuilder
    func toolItems() -> some View {
        Button {
            showImagePicker.toggle()
            data.showPencilKitTools(showTools)
        } label: {
            Image(systemName: "photo.badge.plus")
        }
        
        Button {
            data.insertText(.init("Text"), rect: .zero)
        } label: {
            Image(systemName: "textformat.characters")
        }
        
        Menu("shape") {
            let rect = CGRect(origin: .zero, size: .init(width: 100, height: 100))
            
            Button {
                let configuration = ShapeConfiguration(type: .rectangle, fillColor: UIColor.black.cgColor)
                data.insertShape(configuration, rect: rect)
            } label: {
                Image(systemName: "rectangle")
            }
            
            Button {
                let configuration = ShapeConfiguration(type: .ellipse, fillColor: UIColor.black.cgColor)
                data.insertShape(configuration, rect: rect)
            } label: {
                Image(systemName: "circle")
            }
            
            Button {
                let configuration = ShapeConfiguration(type: .chatBubble, fillColor: UIColor.black.cgColor)
                data.insertShape(configuration, rect: rect)
            } label: {
                Image(systemName: "bubble")
            }
            
            Button {
                let configuration = ShapeConfiguration(type: .arrowShape, fillColor: UIColor.black.cgColor)
                data.insertShape(configuration, rect: rect)
            } label: {
                Image(systemName: "arrow.left")
            }
            
            Button {
                let configuration = ShapeConfiguration(type: .line, fillColor: UIColor.black.cgColor)
                data.insertShape(configuration, rect: rect)
            } label: {
                Image(systemName: "stroke.line.diagonal")
            }
        }
        
        Button {
            showTools.toggle()
            data.showPencilKitTools(showTools)
        } label: {
            Image(systemName: "pencil.and.scribble")
        }
        
        Button {
            Task {
                let rect = CGRect(origin: .zero, size: .init(width: 350, height: 670))
                if let image = await data.exportAsImage(rect, scale: 2) {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        ContentView()
    } else {
        // Fallback on earlier versions
    }
}
