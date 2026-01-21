//
//  SwiftUIView.swift
//  ZineZine
//
//  Created by Dayô Araújo on 20/01/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct DrawingPickerView: View {
    var data: EditorData
    @State private var toolColor: Color = .black
    
    var body: some View {
        HStack(spacing: 30) {
            ColorPicker("", selection: $toolColor)
                .frame(width: 40)
                .onChange(of: toolColor) { _, newValue in data.updateColor(newValue) }
            
            Button {
                data.selectTool(.pen)
            } label: {
                Image("spherographic")
                    .resizable()
                    .frame(width: 30, height: 100)
            }
            
            Button {
                data.selectTool(.pencil)
            } label: {
                Image("pencil")
                    .resizable()
                    .frame(width: 30, height: 100)
            }
            
            Button {
                data.selectTool(.marker)
            } label: {
                Image("highlighter")
                    .resizable()
                    .frame(width: 65, height: 100)
            }
            
            Button {
                data.selectTool(.fountainPen)
            } label: {
                Image("pen")
                    .resizable()
                    .frame(width: 30, height: 100)
            }
            
            Button {
                data.selectTool(.crayon)
            } label: {
                Image("crayon")
                    .resizable()
                    .frame(width: 30, height: 100)
            }
            
            Button {
                data.selectTool(.monoline)
            } label: {
                Image("nanquin")
                    .resizable()
                    .frame(width: 30, height: 100)
            }
            
            Button {
                data.selectEraser()
            } label: {
                Image("eraser")
                    .resizable()
                    .frame(width: 90, height: 100)
            }
        }
        .padding(EdgeInsets(top: 15, leading: 20, bottom: 0, trailing: 50))
        .background(
            RoundedRectangle(cornerRadius: 30)
                .foregroundColor(Color("mediumGray"))
        )
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        ContentView()
    }
}
