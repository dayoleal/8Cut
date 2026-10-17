//
//  LayersPanelView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI
import PhotosUI

/// Layers drawer on the right edge of the editor, below the pages drawer.
/// Layers are listed top first. Drag a layer onto another to reorder.
struct LayersPanelView: View {
    @Bindable var viewModel: EditorViewModel

    /// Item being dragged over, to show the drop indicator.
    @State private var dropTargetID: UUID?

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            DrawerTab(systemName: "square.3.layers.3d",
                      title: "Camadas",
                      isOpen: viewModel.isShowingLayers) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { viewModel.toggleLayersPanel() }
            }
            if viewModel.isShowingLayers {
                panel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .alert("Renomear camada", isPresented: $viewModel.isRenamingLayer) {
            TextField("Nome", text: $viewModel.layerDraftName)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") { viewModel.commitRenameLayer() }
        }
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12 * deviceScale) {
            header

            ScrollView {
                VStack(spacing: 6 * deviceScale) {
                    ForEach(viewModel.layers) { layer in
                        row(for: layer)
                    }
                }
            }
            .scrollIndicators(.hidden)

            if viewModel.activeLayer != nil {
                Divider().overlay(Color.white.opacity(0.15))
                activeLayerSettings
            }
        }
        .padding(14 * deviceScale)
        .frame(width: 250 * deviceScale)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20 * deviceScale, bottomLeadingRadius: 20 * deviceScale)
                .fill(Color.chromeDark)
        )
    }

    private var header: some View {
        HStack(spacing: 8 * deviceScale) {
            Text("Camadas")
                .font(.system(size: 14 * deviceScale, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button { viewModel.addDrawingLayer() } label: {
                ChromeIcon(systemName: "plus", size: 30 * deviceScale)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Nova camada de desenho")

            PhotosPicker(selection: $viewModel.photoSelection, matching: .images) {
                ChromeIcon(systemName: "photo", size: 30 * deviceScale)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adicionar imagem")
        }
    }

    private func row(for layer: ZineLayer) -> some View {
        LayerRow(layer: layer,
                 thumbnail: viewModel.layerThumbnail(layer),
                 isActive: viewModel.isActive(layer),
                 isDropTarget: dropTargetID == layer.id,
                 onToggleVisibility: { viewModel.toggleVisibility(layer.id) },
                 onToggleLock: { viewModel.toggleLock(layer.id) })
            .onTapGesture { viewModel.selectLayer(layer.id) }
            .contextMenu { contextMenu(for: layer) }
            .draggable(layer.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                withAnimation(.snappy) { viewModel.moveLayer(id, onto: layer.id) }
                return true
            } isTargeted: { isTargeted in
                dropTargetID = isTargeted ? layer.id : (dropTargetID == layer.id ? nil : dropTargetID)
            }
    }

    // MARK: - Active layer

    private var activeLayerSettings: some View {
        VStack(alignment: .leading, spacing: 8 * deviceScale) {
            HStack {
                Text("Opacidade")
                Spacer()
                Text("\(Int(viewModel.activeLayerOpacity * 100))%").monospacedDigit()
            }
            .font(.system(size: 12 * deviceScale))
            .foregroundStyle(.white.opacity(0.85))

            Slider(value: $viewModel.activeLayerOpacity, in: 0...1,
                   onEditingChanged: { viewModel.opacityEditingChanged($0) })
                .tint(Color.acidGreen)

            Menu {
                ForEach(LayerFilter.allCases) { filter in
                    Button(filter.displayName) { viewModel.setFilter(filter) }
                }
            } label: {
                settingLabel("Filtro", value: viewModel.activeLayer?.filter.displayName ?? "")
            }

            Menu {
                ForEach(LayerBlendMode.allCases) { mode in
                    Button(mode.displayName) { viewModel.setBlendMode(mode) }
                }
            } label: {
                settingLabel("Mesclagem", value: viewModel.activeLayer?.blendMode.displayName ?? "")
            }

            layerActions
        }
    }

    @ViewBuilder
    private var layerActions: some View {
        if viewModel.activeLayer?.isImage == true {
            HStack(spacing: 8 * deviceScale) {
                actionButton("Recortar", systemImage: "scissors") { viewModel.startCutout() }
                actionButton("Remover fundo", systemImage: "person.crop.rectangle") { viewModel.removeBackground() }
            }
            .disabled(!viewModel.canEditActiveImage)
        } else if viewModel.activeLayer?.isText == true, let id = viewModel.activeLayerID {
            actionButton("Editar texto", systemImage: "character.cursor.ibeam") { viewModel.beginEditingText(id) }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11 * deviceScale, weight: .semibold))
                .foregroundStyle(Color.acidGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8 * deviceScale)
                .background(RoundedRectangle(cornerRadius: 10 * deviceScale).fill(Color.chromeMedium))
        }
        .buttonStyle(.plain)
    }

    private func settingLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.acidGreen)
            Image(systemName: "chevron.up.chevron.down")
                .foregroundStyle(Color.acidGreen)
        }
        .font(.system(size: 12 * deviceScale))
        .foregroundStyle(.white.opacity(0.85))
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for layer: ZineLayer) -> some View {
        Button("Renomear", systemImage: "character.cursor.ibeam") { viewModel.beginRenameLayer(layer.id) }
        Button("Duplicar", systemImage: "plus.square.on.square") { viewModel.duplicateLayer(layer.id) }
        Button("Mover para cima", systemImage: "arrow.up") { viewModel.moveLayerUp(layer.id) }
            .disabled(!viewModel.canMoveUp(layer))
        Button("Mover para baixo", systemImage: "arrow.down") { viewModel.moveLayerDown(layer.id) }
            .disabled(!viewModel.canMoveDown(layer))
        Divider()
        Button("Apagar", systemImage: "trash", role: .destructive) { viewModel.deleteLayer(layer.id) }
            .disabled(!viewModel.canDeleteLayers)
    }
}

/// Row of the layers drawer.
struct LayerRow: View {
    let layer: ZineLayer
    let thumbnail: UIImage?
    let isActive: Bool
    /// Shows a line where a dragged layer will go.
    var isDropTarget: Bool = false
    let onToggleVisibility: () -> Void
    let onToggleLock: () -> Void

    var body: some View {
        HStack(spacing: 10 * deviceScale) {
            ZStack {
                Color.white
                if let thumbnail {
                    Image(uiImage: thumbnail).resizable()
                }
            }
            .frame(width: 28 * deviceScale, height: 28 * deviceScale / ZineFormat.pageAspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 4 * deviceScale))

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.system(size: 12 * deviceScale, weight: isActive ? .bold : .regular))
                    .lineLimit(1)
                Text(layer.isDrawing ? "Desenho" : (layer.isText ? "Texto" : "Imagem"))
                    .font(.system(size: 9 * deviceScale))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            Button(action: onToggleLock) {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(layer.isLocked ? Color.acidGreen : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isLocked ? "Desbloquear" : "Bloquear")

            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? Color.acidGreen : .white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isVisible ? "Esconder" : "Mostrar")
        }
        .font(.system(size: 13 * deviceScale))
        .padding(8 * deviceScale)
        .background(
            RoundedRectangle(cornerRadius: 12 * deviceScale)
                .fill(isActive ? Color.chromeHighlight : Color.chromeMedium.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12 * deviceScale)
                .stroke(Color.acidGreen, lineWidth: isDropTarget ? 2 : 0)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Open", traits: .portrait) {
    HStack {
        Spacer()
        LayersPanelView(viewModel: PreviewData.editorViewModel(isShowingLayers: true))
    }
    .padding(.vertical, 40)
    .background(DeskBackground(style: .editor))
}

#Preview("Closed", traits: .portrait) {
    HStack {
        Spacer()
        LayersPanelView(viewModel: PreviewData.editorViewModel())
    }
    .padding(.vertical, 40)
    .background(DeskBackground(style: .editor))
}
