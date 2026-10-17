//
//  PageDrawerView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Page drawer attached to the right edge of the editor.
///
/// Closed, it shows a small tab; open, a narrow panel lists the 8 pages in
/// reading order, with the current one on a gray highlight that runs into the
/// screen edge. Measurements are in points on the 11-inch iPad and multiplied
/// by `deviceScale`.
struct PageDrawerView: View {
    @Bindable var viewModel: EditorViewModel

    /// Visible width of the open panel.
    private var panelWidth: CGFloat { 74 * deviceScale }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            tab
            if viewModel.isPageDrawerOpen {
                pageList
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Tab

    private var tab: some View {
        let isOpen = viewModel.isPageDrawerOpen
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { viewModel.togglePageDrawer() }
        } label: {
            VStack(spacing: 4 * deviceScale) {
                Image(systemName: "square.fill.on.square.fill")
                    .font(.system(size: 18 * deviceScale, weight: .semibold))
                if !isOpen {
                    Text("Páginas")
                        .font(.system(size: 12 * deviceScale, weight: .semibold))
                }
            }
            .foregroundStyle(Color.acidGreen)
            .frame(width: (isOpen ? 48 : 70) * deviceScale, height: (isOpen ? 52 : 64) * deviceScale)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 16 * deviceScale,
                                       bottomLeadingRadius: isOpen ? 0 : 16 * deviceScale)
                    .fill(Color.chromeDark)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Fechar páginas" : "Abrir páginas")
    }

    // MARK: - List

    private var pageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .trailing, spacing: 16 * deviceScale) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        Button {
                            viewModel.selectPage(index)
                        } label: {
                            PageDrawerItem(image: viewModel.thumbnail(for: page),
                                           paper: page.paperColor.color,
                                           label: viewModel.label(forPage: index),
                                           isSelected: viewModel.isSelected(page: index))
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.vertical, 12 * deviceScale)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.pageIndex) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .frame(width: panelWidth)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 20 * deviceScale, bottomLeadingRadius: 20 * deviceScale)
                .fill(Color.chromeDark)
        )
    }
}

/// A page thumbnail with its label. The selected page is slightly larger and
/// sits on a gray highlight that runs into the screen edge.
struct PageDrawerItem: View {
    let image: UIImage?
    let paper: Color
    let label: String
    let isSelected: Bool

    private var thumbnailWidth: CGFloat { (isSelected ? 52 : 48) * deviceScale }

    var body: some View {
        VStack(alignment: .leading, spacing: 5 * deviceScale) {
            ZStack {
                paper
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.medium)
                }
            }
            .frame(width: thumbnailWidth, height: thumbnailWidth / ZineFormat.pageAspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 10 * deviceScale))

            Text(label)
                .font(.system(size: (isSelected ? 12 : 9) * deviceScale,
                              weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? .white : Color(white: 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, 6 * deviceScale)
                // Never wider than the thumbnail, so long labels ("Contracapa")
                // don't push the column out of alignment.
                .frame(width: thumbnailWidth, alignment: .leading)
        }
        .padding(.leading, isSelected ? 8 * deviceScale : 0)
        .padding(.trailing, 2 * deviceScale)
        .padding(.vertical, isSelected ? 6 * deviceScale : 0)
        .background(alignment: .trailing) {
            if isSelected {
                UnevenRoundedRectangle(topLeadingRadius: 18 * deviceScale, bottomLeadingRadius: 18 * deviceScale)
                    .fill(Color.chromeHighlight)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("Open drawer", traits: .portrait) {
    HStack {
        Spacer()
        PageDrawerView(viewModel: PreviewData.editorViewModel(isPageDrawerOpen: true))
    }
    .padding(.vertical, 40)
    .background(DeskBackground(style: .editor))
}

#Preview("Closed drawer", traits: .portrait) {
    VStack {
        HStack {
            Spacer()
            PageDrawerView(viewModel: PreviewData.editorViewModel())
        }
        Spacer()
    }
    .padding(.vertical, 40)
    .background(DeskBackground(style: .editor))
}
