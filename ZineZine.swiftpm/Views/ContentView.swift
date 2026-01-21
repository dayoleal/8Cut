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
    @State private var showImagePicker: Bool = false
    @State var showTools: Bool = false
    
    private let canvasSize = CGSize(width: 740, height: 548)
    private let exportRect = CGRect(x: 0, y: 0, width: 350, height: 670)
    
    var body: some View {
        NavigationStack {
            ZStack {
                EditorView(data: data, size: canvasSize)
                
                VStack {
                    AllTools(data: data)
                        .padding(.top, 30)
                    
                    Spacer()
                    
                    DrawingPickerView(data: data)
                }
            }
            .ignoresSafeArea()
        }
    }
}

@available(iOS 26.0, *)
#Preview (traits: .landscapeLeft){
    ContentView()
}
