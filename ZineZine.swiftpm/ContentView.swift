//
//  ContentView.swift/Users/dayoleal/Desktop/Zine/ZineZine.swiftpm/ContentView.swift
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
            ZStack {
                EditorView(data: data, size: .init(width: 800, height: 548))
                VStack {
                    tools()
                    Spacer()
                }
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
    func tools() -> some View {
        HStack {
            HStack {
                Button(action: { showImagePicker.toggle() }) { }
                .buttonStyle(ToolButtons(symbol: "house"))
                
                Button(action: { showImagePicker.toggle() }) { }
                .buttonStyle(ToolButtons(symbol: "photo.badge.plus"))
                
                Button(action: { data.insertText(.init("Text"), rect: .zero) }) { }
                .buttonStyle(ToolButtons(symbol: "textformat.size"))
                
                Button(action: {
                    showTools.toggle()
                    data.showPencilKitTools(showTools)
                }) { }
                .buttonStyle(ToolButtons(symbol: "pencil.and.scribble"))
                
                Menu {
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
                } label: {
                    Image(systemName: "squareshape.controlhandles.on.squareshape.controlhandles")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color("acidGreen"))
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .foregroundColor(Color("mediumGray"))
                        )
                }
                
                Menu {
                    let canvasRect = CGRect(origin: .zero, size: .init(width: 800, height: 548))

                    Button ("Black and White"){
                        Task {
                            await data.applyFilterToCanvas(CIFilter.photoEffectMono(), rect: canvasRect)
                        }
                    }

                    Button ("Inverted Colors"){
                        Task {
                            await data.applyFilterToCanvas(CIFilter.colorInvert(), rect: canvasRect)
                        }
                    }
                    
                    Divider()

                    Button ("Revert Filters", role: .destructive){
                        data.revertFilters()
                    }

                } label: {
                    Image(systemName: "camera.filters")
                        .font(.title)
                        .bold()
                        .foregroundColor(Color("acidGreen"))
                        .frame(width: 70, height: 70)
                        .background(Circle().foregroundColor(Color("mediumGray")))
                }
            }
            .padding(10)
            .background(
                Capsule()
                    .foregroundColor(Color("darkGray"))
            )
            
            Spacer()
            
            Button {
                Task {
                    let rect = CGRect(origin: .zero, size: .init(width: 350, height: 670))
                    if let image = await data.exportAsImage(rect, scale: 2) {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .bold()
                    .foregroundColor(Color("acidGreen"))
                    .frame(width: 70, height: 70)
                    .background(
                        Circle()
                            .foregroundColor(Color("mediumGray"))
                    )
            }
            .padding(10)
            .background(
                Circle()
                    .foregroundColor(Color("darkGray"))
            )
        }
        .padding(.horizontal, 35)
    }
}

struct ToolButtons: ButtonStyle {
    var symbol: String

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
        Image(systemName: symbol)
            .font(.title2)
            .bold()
            .foregroundColor(Color("acidGreen"))
            .frame(width: 70, height: 70)
            .background(
                Circle()
                    .foregroundColor(Color("mediumGray"))
            )
    }
}

@available(iOS 26.0, *)
#Preview (traits: .landscapeLeft){
    ContentView()
}
