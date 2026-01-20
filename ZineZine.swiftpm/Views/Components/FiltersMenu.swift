//
//  FiltersMenu.swift
//  ZineZine
//
//  Created by Dayô Araújo on 20/01/26.
//
import SwiftUI

@available(iOS 26.0, *)
struct FiltersMenu: View {
    let data: EditorData
    let canvasRect: CGRect
    
    var body: some View {
        Menu {
            Button("Black and White") {
                Task { await data.applyFilterToCanvas(CIFilter.photoEffectMono(), rect: canvasRect) }
            }
            
            Button("Inverted Colors") {
                Task { await data.applyFilterToCanvas(CIFilter.colorInvert(), rect: canvasRect) }
            }
            
            Divider()
            
            Button("Revert Filters", role: .destructive) { data.revertFilters() }
        } label: {
            Image(systemName: "camera.filters")
                .font(.title)
                .fontWeight(.heavy)
                .frame(width: 70, height: 70)
                .background(Circle().foregroundColor(Color("mediumGray")))
        }
    }
}
