//
//  SwiftUIView.swift
//  ZineZine
//
//  Created by Dayô Araújo on 20/01/26.
//

import SwiftUI
import _PhotosUI_SwiftUI

@available(iOS 26.0, *)
struct AllTools: View {
    var data: EditorData
    @State private var showTools: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var photoItem: PhotosPickerItem?
    
    private let canvasSize = CGSize(width: 800, height: 548)
    private let exportRect = CGRect(x: 0, y: 0, width: 350, height: 670)
    
    var body: some View {
        NavigationStack {
            HStack {
                HStack {
                    Button(action: { showImagePicker.toggle() }) { }
                        .buttonStyle(ToolButtons(symbol: "photo.badge.plus"))
                    
                    Button(action: { data.insertText(.init("Text"), rect: .zero) }) { }
                        .buttonStyle(ToolButtons(symbol: "textformat.size"))
                    
                    Button(action: togglePencilKit) { }
                        .buttonStyle(ToolButtons(symbol: "pencil.and.scribble"))
                    
                    ShapesMenu(data: data)
                    
                    FiltersMenu(data: data, canvasRect: CGRect(origin: .zero, size: canvasSize))
                }
                .padding(10)
                .background(Capsule().foregroundColor(Color("darkGray")))
                
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
        .photosPicker(isPresented: $showImagePicker, selection: $photoItem)
        .onChange(of: photoItem) { _, newValue in
            handlePhotoSelection(newValue)
        }
    }
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let imageData = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: imageData) {
                let rect = CGRect(origin: .zero, size: .init(width: 100, height: 100))
                data.insertImage(image, rect: rect)
            }
            photoItem = nil
        }
    }
    
    private func exportImage() {
        Task {
            if let image = await data.exportAsImage(exportRect, scale: 2) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }
    
    private func togglePencilKit() {
        showTools.toggle()
        data.showPencilKitTools(showTools)
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
