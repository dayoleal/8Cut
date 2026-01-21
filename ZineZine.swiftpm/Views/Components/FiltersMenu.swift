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
            Button("Xerox") {
                let filter = CIFilter.dotScreen()
                    filter.center = CGPoint(x: canvasRect.midX, y: canvasRect.midY)
                    filter.width = 2.8
                    filter.sharpness = 0.7
                    Task { await data.applyFilterToCanvas(filter, rect: canvasRect) }
            }
            
            Button("Cyanotype") {
                let filter = CIFilter.colorMonochrome()
                filter.color = CIColor(red: 0.0, green: 0.2, blue: 0.5)
                filter.intensity = 0.97
                
                Task { await data.applyFilterToCanvas(filter, rect: canvasRect)
                }
            }
            
            Button("Negative") {
                Task {
                    await data.applyFilterToCanvas(CIFilter.colorInvert(), rect: canvasRect)
                }
            }
            
            Button("Red & Blue") {
                let filter = CIFilter.falseColor()

                filter.color0 = CIColor(red: 0.0, green: 0.05, blue: 0.4)

                filter.color1 = CIColor(red: 0.8, green: 0.0, blue: 0.0)
                
                Task { await data.applyFilterToCanvas(filter, rect: canvasRect) }
            }
            
            Divider()
            
            Button("Revert Filters", role: .destructive) {
                data.revertFilters()
            }
        } label: {
            Image(systemName: "camera.filters")
                .font(.title)
                .fontWeight(.heavy)
                .frame(width: 70, height: 70)
                .background(Circle().foregroundColor(Color("mediumGray")))
        }
    }
}
