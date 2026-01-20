//
//  GridView.swift
//  ZineZine
//
//  Created by Dayô Araújo on 12/01/26.
//

import SwiftUI

struct GridView: View {
    var rows: Int = 2
    var cols: Int = 4
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(1..<cols, id: \.self) { i in
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 1)
                        .offset(x: (geo.size.width / CGFloat(cols)) * CGFloat(i))
                }
                
                ForEach(1..<rows, id: \.self) { i in
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(height: 1)
                        .offset(y: (geo.size.height / CGFloat(rows)) * CGFloat(i))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
