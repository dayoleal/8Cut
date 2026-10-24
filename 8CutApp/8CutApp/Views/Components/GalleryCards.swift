//
//  GalleryCards.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Zine card of the gallery grid.
struct ZineCard: View {
    let item: ZineSummary
    /// Saved cover.
    let cover: UIImage?

    var body: some View {
        BookCoverView(title: item.title, image: cover, showsDefaultCover: !item.hasCoverArt)
            .accessibilityElement()
            .accessibilityLabel(item.title)
    }
}

/// "+" card that creates a new zine.
struct NewZineCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Rectangle()
                .strokeBorder(Color.acidGreen, style: StrokeStyle(lineWidth: 4, dash: [12, 9]))
                .aspectRatio(ZineFormat.pageAspectRatio, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(Color.acidGreen)
                }
                .contentShape(Rectangle())
                .padding(.trailing, 14)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Nova revista")
    }
}

// MARK: - Previews

#Preview {
    HStack(alignment: .top, spacing: 56) {
        NewZineCard {}
        ZineCard(item: ZineSummary(id: UUID(), title: "Zine", createdAt: .now,
                                   modifiedAt: .now, hasCoverArt: false),
                 cover: nil)
    }
    .frame(width: 640)
    .padding(40)
    .background(DeskBackground(style: .gallery))
}
