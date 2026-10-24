//
//  ToolSheet.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Tool tray at the bottom of the editor. Sizes are in points on the 11-inch iPad
/// and multiplied by ``scale``.
struct ToolSheet: View {
    @Bindable var viewModel: EditorViewModel

    private var tools: ToolPaletteViewModel { viewModel.tools }

    /// Content width on the 11-inch iPad, in points.
    private static let designContentWidth: CGFloat = 710

    /// `deviceScale`, reduced when the window is too narrow for the tray.
    private var scale: CGFloat {
        let fitting = (width - 48) / Self.designContentWidth
        return max(min(deviceScale, fitting), 0.5)
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            if viewModel.isToolSheetExpanded {
                HStack(alignment: .top, spacing: 0) {
                    toolTray
                    swatchGrid
                        .padding(.leading, 20.5 * scale)
                    optionsButton
                        .padding(.leading, 25 * scale)
                        .frame(height: swatchGridHeight)
                }
                .padding(.leading, 41.5 * scale)
                .padding(.trailing, 25 * scale)
                .frame(height: TrayItemView.visibleHeight * scale, alignment: .top)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: Self.designContentWidth * scale)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 30 * scale, topTrailingRadius: 30 * scale)
                .fill(Color.chromeDark)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.4), radius: 12, y: -2)
        )
    }

    // MARK: - Grabber

    private var grabber: some View {
        Capsule()
            .fill(Color(white: 0.4))
            .frame(width: 34 * scale, height: 5 * scale)
            .padding(.top, 12.5 * scale)
            .padding(.bottom, 21 * scale)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { viewModel.toggleToolSheet() }
            }
            .gesture(
                DragGesture(minimumDistance: 10).onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.handleToolSheetDrag(translation: value.translation.height)
                    }
                }
            )
            .accessibilityLabel(viewModel.isToolSheetExpanded ? "Recolher ferramentas" : "Mostrar ferramentas")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tray

    private var toolTray: some View {
        HStack(alignment: .top, spacing: 16.5 * scale) {
            ForEach(tools.trayItems) { item in
                let isRaised = tools.isRaised(item)
                let itemWidth = item.designWidth * scale
                TrayItemView(asset: item.assetName,
                             width: itemWidth,
                             height: tools.artworkHeight(for: item, width: itemWidth),
                             lift: isRaised ? 10 * scale : 0) {
                    tools.select(item)
                }
                .accessibilityLabel(item.displayName)
                .accessibilityAddTraits(isRaised ? .isSelected : [])
            }
        }
    }

    // MARK: - Colors

    private var swatchDiameter: CGFloat { 34 * scale }
    private var swatchGridHeight: CGFloat { swatchDiameter * 2 + 13.5 * scale }

    private var swatchGrid: some View {
        Grid(horizontalSpacing: 12.5 * scale, verticalSpacing: 13.5 * scale) {
            GridRow {
                swatch(tools.swatches[0])
                swatch(tools.swatches[1])
                swatch(tools.swatches[2])
            }
            GridRow {
                swatch(tools.swatches[3])
                swatch(tools.swatches[4])
                ColorPicker("Outra cor", selection: Binding(
                    get: { tools.color.color },
                    set: { tools.select(RGBAColor($0)) }
                ), supportsOpacity: false)
                .labelsHidden()
                // The system color well is about 28 pt wide.
                .scaleEffect(swatchDiameter / 28)
                .frame(width: swatchDiameter, height: swatchDiameter)
            }
        }
    }

    private func swatch(_ color: RGBAColor) -> some View {
        let isSelected = tools.isSelected(color)
        return Button {
            tools.select(color)
        } label: {
            ZStack {
                if isSelected {
                    Circle().stroke(.white, lineWidth: 3 * scale)
                    Circle().fill(color.color).padding(5 * scale)
                } else {
                    Circle().fill(color.color)
                }
            }
            .frame(width: swatchDiameter, height: swatchDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options

    private var optionsButton: some View {
        Button {
            tools.showOptions()
        } label: {
            ChromeIcon(systemName: "ellipsis", size: 35 * scale)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Opções da ferramenta")
        .popover(isPresented: Bindable(tools).isShowingOptions, arrowEdge: .bottom) {
            ToolOptionsView(tools: tools)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - TrayItemView

/// Tool image in the tray. Moves up when selected.
struct TrayItemView: View {
    /// Tray height on the 11-inch iPad, in points.
    static let visibleHeight: CGFloat = 90

    let asset: String
    /// Image size.
    let width: CGFloat
    let height: CGFloat
    /// Upward offset.
    let lift: CGFloat
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        } label: {
            Image(asset)
                .resizable()
                .frame(width: width, height: height)
                .offset(y: -lift)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ToolOptionsView

/// Options popover: width, opacity and finger drawing.
struct ToolOptionsView: View {
    @Bindable var tools: ToolPaletteViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OptionSlider(title: "Espessura", value: $tools.width)
            OptionSlider(title: "Opacidade", value: $tools.opacity, range: 0.05...1)
                .disabled(!tools.isOpacityEnabled)
            
            Toggle(isOn: $tools.allowsFingerDrawing) {
                Label("Desenhar com o dedo", systemImage: "hand.draw")
            }
            .tint(Color.acidGreen)
        }
        .padding(24)
        .frame(width: 340)
        .background(Color.chromeDark)
        .preferredColorScheme(.dark)
    }
}

/// A labeled percentage slider.
private struct OptionSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))%").monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            Slider(value: $value, in: range)
                .tint(Color.acidGreen)
        }
    }
}

// MARK: - Previews

#Preview("Tool sheet", traits: .landscapeLeft) {
    VStack {
        Spacer()
        ToolSheet(viewModel: PreviewData.editorViewModel())
    }
    .background(DeskBackground(style: .editor))
}
//
//#Preview("Options") {
//    ToolOptionsView(tools: ToolPaletteViewModel())
//}
