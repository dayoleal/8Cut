//
//  ExportSheet.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Export options: print sheet, pages PDF or images.
struct ExportSheet: View {
    @Bindable var viewModel: ExportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Formato", selection: $viewModel.format) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(viewModel.format.details)
                }

                if viewModel.format == .printSheet {
                    printSheetOptions
                }
            }
            .navigationTitle("Exportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isExporting {
                        ProgressView()
                    } else {
                        Button("Exportar") { viewModel.export() }
                            .bold()
                    }
                }
            }
            .sheet(item: $viewModel.sharedFiles) { files in
                ActivityView(items: files.urls)
            }
            .alert("Algo deu errado", isPresented: $viewModel.isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .tint(Color.acidGreen)
    }

    private var printSheetOptions: some View {
        Section {
            Picker("Papel", selection: $viewModel.paper) {
                ForEach(PaperSize.allCases) { paper in
                    Text(paper.displayName).tag(paper)
                }
            }
            Toggle("Linhas de corte e dobra", isOn: $viewModel.showsGuides)

            Image(uiImage: viewModel.sheetPreview)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .padding(.vertical, 8)
        } header: {
            Text("Folha")
        } footer: {
            Text("""
            Imprima em paisagem, em tamanho real (100%). Dobre a folha ao meio nos dois \
            sentidos, corte só a linha tracejada do centro e dobre de novo, empurrando o \
            corte para formar a zine.
            """)
        }
    }
}

// MARK: - Previews

#Preview {
    ExportSheet(viewModel: ExportViewModel(document: PreviewData.document()))
}
