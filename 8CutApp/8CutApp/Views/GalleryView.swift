//
//  GalleryView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Gallery screen ("Suas Revistas").
struct GalleryView: View {
    @Bindable var viewModel: GalleryViewModel
    @FocusState private var isSearchFocused: Bool

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 260 * deviceScale, maximum: 340 * deviceScale),
                  spacing: 56 * deviceScale, alignment: .top)]
    }

    var body: some View {
        ZStack {
            DeskBackground(style: .gallery)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    if viewModel.isSearching { searchField }
                    grid
                }
                .padding(.horizontal, 64)
                .padding(.top, 24)
                .padding(.bottom, 64)
            }
            .scrollIndicators(.hidden)
        }
        .alert("Renomear revista", isPresented: $viewModel.isRenaming) {
            TextField("Título", text: $viewModel.draftTitle)
            Button("Cancelar", role: .cancel) { viewModel.cancelRename() }
            Button("Salvar") { viewModel.commitRename() }
        }
        .confirmationDialog(viewModel.deletionTitle,
                            isPresented: $viewModel.isConfirmingDeletion,
                            titleVisibility: .visible) {
            Button("Apagar revista", role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.confirmDeletion()
                }
            }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
        .alert("Algo deu errado", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Suas Revistas")
                .font(.system(size: 48 * deviceScale, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

            Spacer()

            HStack(spacing: 10) {
                Menu {
                    Picker("Ordenar por", selection: $viewModel.sortOrder) {
                        ForEach(ZineSortOrder.allCases) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                } label: {
                    ChromeIcon(systemName: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Ordenar")

                ChromeIconButton(systemName: "magnifyingglass", isActive: viewModel.isSearching) {
                    withAnimation(.snappy) { viewModel.toggleSearch() }
                    isSearchFocused = viewModel.isSearching
                }
                .accessibilityLabel("Buscar")
            }
            .chromeCapsule()
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.acidGreen)
            TextField("Buscar revista", text: $viewModel.query)
                .focused($isSearchFocused)
                .foregroundStyle(.white)
                .submitLabel(.search)
        }
        .font(.title3)
        .padding(.horizontal, 22)
        .frame(height: 56)
        .background(Capsule().fill(Color.chromeDark))
        .frame(maxWidth: 480)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
            if viewModel.showsNewZineCard {
                NewZineCard { viewModel.createZine() }
            }
            ForEach(viewModel.visibleItems) { item in
                Button {
                    viewModel.open(item)
                } label: {
                    ZineCard(item: item, cover: viewModel.coverImage(for: item))
                }
                .buttonStyle(PressableCardStyle())
                .contextMenu { contextMenu(for: item) }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.4, anchor: .bottom).combined(with: .opacity)
                ))
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: ZineSummary) -> some View {
        Button("Abrir no editor", systemImage: "pencil.and.scribble") {
            viewModel.open(item, inEditor: true)
        }
        Button("Renomear", systemImage: "character.cursor.ibeam") {
            viewModel.beginRename(item)
        }
        Button("Duplicar", systemImage: "plus.square.on.square") {
            withAnimation(.snappy) { viewModel.duplicate(item) }
        }
        Divider()
        Button("Apagar", systemImage: "trash", role: .destructive) {
            viewModel.requestDeletion(item)
        }
    }
}

// MARK: - Previews

#Preview("Gallery", traits: .landscapeLeft) {
    GalleryView(viewModel: PreviewData.galleryViewModel())
}

#Preview("Gallery portrait", traits: .portrait) {
    GalleryView(viewModel: PreviewData.galleryViewModel())
}
