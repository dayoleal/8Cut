//
//  TextEditorSheet.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Sheet to edit a text layer: text, font, size, color and alignment.
struct TextEditorSheet: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $viewModel.editingTextContent.text)
                        .font(.custom(viewModel.editingTextContent.font.postScriptName, size: 22))
                        .frame(minHeight: 140)
                }

                Section("Estilo") {
                    Picker("Fonte", selection: $viewModel.editingTextContent.font) {
                        ForEach(TextFont.allCases) { font in
                            Text(font.displayName)
                                .font(.custom(font.postScriptName, size: 17))
                                .tag(font)
                        }
                    }

                    HStack {
                        Text("Tamanho")
                        Slider(value: $viewModel.editingTextContent.fontSize, in: 24...240)
                            .tint(Color.acidGreen)
                        Text("\(Int(viewModel.editingTextContent.fontSize))")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    ColorPicker("Cor", selection: Binding(
                        get: { viewModel.editingTextContent.color.color },
                        set: { viewModel.editingTextContent.color = RGBAColor($0) }
                    ), supportsOpacity: false)

                    Picker("Alinhamento", selection: $viewModel.editingTextContent.alignment) {
                        ForEach(TextAlignmentOption.allCases) { alignment in
                            Image(systemName: alignment.systemImage).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Texto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { viewModel.cancelTextEditing() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { viewModel.commitTextEditing() }
                        .bold()
                }
            }
        }
        .tint(Color.acidGreen)
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Previews

#Preview {
    let viewModel = PreviewData.editorViewModel()
    TextEditorSheet(viewModel: viewModel)
        .onAppear { viewModel.addText() }
}
