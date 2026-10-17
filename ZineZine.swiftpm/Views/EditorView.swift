//
//  EditorView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// The editing screen
struct EditorView: View {
    @Bindable var viewModel: EditorViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                DeskBackground(style: .editor)

                PageCanvasView(viewModel: viewModel)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar(isLandscape: isLandscape)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                    Spacer()
                }

                PageDrawerView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, (isLandscape ? 100 : 120) * deviceScale)
                    .padding(.bottom, (viewModel.isToolSheetExpanded ? 150 : 40) * deviceScale)
                    .ignoresSafeArea(edges: .trailing)

                VStack {
                    Spacer()
                    ToolSheet(viewModel: viewModel)
                        .id(isLandscape)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(keyboardShortcuts)
        .onAppear { viewModel.layoutScale = deviceScale }
        .animation(.snappy, value: viewModel.pageIndex)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.sceneDidLeaveForeground() }
        }
        .sheet(item: $viewModel.shareItems) { items in
            ActivityView(items: items.images)
        }
    }

    // MARK: - Top bar

    private func topBar(isLandscape: Bool) -> some View {
        HStack(spacing: 12) {
            actions
            if isLandscape { undoRedo }
            Spacer()
            if !isLandscape { undoRedo }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            ChromeIconButton(systemName: "house") { viewModel.close() }
                .accessibilityLabel("Galeria")

            ChromeIconButton(systemName: "photo.badge.plus", isEnabled: false) {}
                .accessibilityLabel("Adicionar imagem")
            ChromeIconButton(systemName: "textformat.size", isEnabled: false) {}
                .accessibilityLabel("Adicionar texto")

            ChromeIconButton(systemName: "pencil.and.scribble") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.toggleToolSheet()
                }
            }
            .accessibilityLabel(viewModel.isToolSheetExpanded ? "Esconder ferramentas" : "Mostrar ferramentas")

            ChromeIconButton(systemName: "square.and.arrow.up") { viewModel.share() }
                .accessibilityLabel("Compartilhar")
        }
        .chromeCapsule()
    }

    private var undoRedo: some View {
        HStack(spacing: 10) {
            ChromeIconButton(systemName: "arrow.left", isEnabled: viewModel.canUndo) { viewModel.undo() }
                .accessibilityLabel("Desfazer")
            ChromeIconButton(systemName: "arrow.right", isEnabled: viewModel.canRedo) { viewModel.redo() }
                .accessibilityLabel("Refazer")
        }
        .chromeCapsule()
    }

    private var keyboardShortcuts: some View {
        ZStack {
            Button("Desfazer") { viewModel.undo() }
                .keyboardShortcut("z", modifiers: .command)
            Button("Refazer") { viewModel.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            Button("Página anterior") { viewModel.goToPreviousPage() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Próxima página") { viewModel.goToNextPage() }
                .keyboardShortcut("]", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Editor", traits: .landscapeLeft) {
    EditorView(viewModel: PreviewData.editorViewModel())
}

#Preview("Editor portrait", traits: .portrait) {
    EditorView(viewModel: PreviewData.editorViewModel())
}
