//
//  PageDrawerView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Page list on the right edge of the editor. Sizes are in points on the 11-inch
/// iPad and multiplied by `deviceScale`.
struct PageDrawerView: View {
    @Bindable var viewModel: EditorViewModel

    /// Width of the open panel.
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
        DrawerTab(systemName: "square.fill.on.square.fill",
                  title: "Páginas",
                  isOpen: viewModel.isPageDrawerOpen) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { viewModel.togglePageDrawer() }
        }
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

/// Page thumbnail and label. The selected page is larger and highlighted.
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
                // Keeps long labels ("Contracapa") from widening the item.
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
