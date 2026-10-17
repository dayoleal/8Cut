//
//  RootView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Shows the screen selected by the ``AppViewModel``.
struct RootView: View {
    let viewModel: AppViewModel

    var body: some View {
        ZStack {
            switch viewModel.screen {
            case .gallery:
                GalleryView(viewModel: viewModel.galleryViewModel)
                    .transition(.opacity)

            case .reader(let readerViewModel):
                ZineReaderView(viewModel: readerViewModel)
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity),
                                            removal: .opacity))

            case .editor(let editorViewModel):
                EditorView(viewModel: editorViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.screen.id)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview(traits: .landscapeLeft) {
    RootView(viewModel: AppViewModel(repository: PreviewData.repository()))
}
