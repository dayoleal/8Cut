//
//  ZineReaderView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Reading mode: the zine lying on the desk, to leaf through before editing,
/// sharing or deleting it. Renders ``ReaderViewModel`` state.
struct ZineReaderView: View {
    @Bindable var viewModel: ReaderViewModel

    var body: some View {
        ZStack {
            DeskBackground(style: .reader)

            VStack(spacing: 0) {
                header
                    .padding(.top, 32)

                BookSpreadView(viewModel: viewModel)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)

                actionBar
                    .padding(.bottom, 40)
            }

            VStack {
                HStack {
                    ChromeBackButton { viewModel.close() }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
        }
        .alert("Renomear revista", isPresented: $viewModel.isRenaming) {
            TextField("Título", text: $viewModel.draftTitle)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") { viewModel.commitRename() }
        }
        .confirmationDialog(viewModel.deletionTitle,
                            isPresented: $viewModel.isConfirmingDeletion,
                            titleVisibility: .visible) {
            Button("Apagar revista", role: .destructive) { viewModel.confirmDeletion() }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
        .sheet(item: $viewModel.shareItems) { items in
            ActivityView(items: items.images)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Text(viewModel.title)
                .font(.system(size: 44 * deviceScale, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .onTapGesture { viewModel.beginRename() }

            Label {
                Text("\(viewModel.currentPageNumber) / \(viewModel.pageCount)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: viewModel.currentPageNumber)
            } icon: {
                Image(systemName: "square.fill.on.square")
            }
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        }
        .padding(.horizontal, 140)
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Renomear", systemImage: "character.cursor.ibeam") { viewModel.beginRename() }
                Button("Duplicar", systemImage: "plus.square.on.square") { viewModel.duplicate() }
            } label: {
                ChromeIcon(systemName: "ellipsis")
            }
            .accessibilityLabel("Mais opções")

            ChromeIconButton(systemName: "trash") { viewModel.requestDeletion() }
                .accessibilityLabel("Apagar revista")

            ChromeIconButton(systemName: "pencil.and.scribble") { viewModel.edit() }
                .accessibilityLabel("Editar")

            ChromeIconButton(systemName: "square.and.arrow.up") { viewModel.share() }
                .accessibilityLabel("Compartilhar")
        }
        .chromeCapsule()
    }
}

// MARK: - Previews

#Preview("Reader", traits: .landscapeLeft) {
    ZineReaderView(viewModel: ReaderViewModel(document: PreviewData.document()))
}

#Preview("Reader portrait", traits: .portrait) {
    ZineReaderView(viewModel: ReaderViewModel(document: PreviewData.document()))
}
