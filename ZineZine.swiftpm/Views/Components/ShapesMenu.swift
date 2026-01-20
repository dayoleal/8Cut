//
//  ShapesMenu.swift
//  ZineZine
//
//  Created by Dayô Araújo on 20/01/26.
//
import SwiftUI
import PaperKit

@available(iOS 26.0, *)
struct ShapesMenu: View {
    let data: EditorData
    
    var body: some View {
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
    }
}
